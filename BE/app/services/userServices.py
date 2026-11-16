from datetime import datetime, time, timezone
import logging

from fastapi import HTTPException
from prisma.errors import UniqueViolationError

from app.repositories.userRepositories import UserRepository
from app.core.security import create_access_token, hash_password, verify_password
from app.core.db import db
from app.services.consentService import ConsentService, ConsentConflict
from app.core import storage


class UserService:
    def __init__(self):
        self.user_repo = UserRepository()

    async def register_user(self, user_data: dict):
        if not user_data["age_over_14_confirmed"]:
            raise ValueError("만 14세 이상만 가입할 수 있습니다.")
        # 1. 비즈니스 로직: 아이디 중복 체크
        existing_user = await self.user_repo.find_by_id(user_data['id'])
        if existing_user:
            raise ValueError("이미 있는 아이디입니다.")

        # 2. 비밀번호를 해시로 변환한 뒤 저장 (평문 저장 금지)
        # DB 컬럼명(login_id/password_hash)이 API 요청 필드명(id/password)과 다르므로 매핑
        create_data = {
            "login_id": user_data["id"],
            "password_hash": hash_password(user_data["password"]),
            "name": user_data["name"],
            "age_confirmed_at": datetime.now(timezone.utc),
        }
        consent_service = ConsentService()
        try:
            async with db.tx() as tx:
                await consent_service.validate(user_data["consents"], tx, signup=True)
                created_user = await self.user_repo.create_user(create_data, tx)
                await consent_service.repo.append(tx, created_user.user_id, user_data["consents"])
        except UniqueViolationError as exc:
            raise ValueError("이미 있는 아이디입니다.") from exc
        # 응답 스키마(UserData)는 외부 API 계약상 필드명이 id라 DB의 login_id를 매핑해서 돌려줌
        return {
            "user_id": created_user.user_id,
            "id": created_user.login_id,
            "name": created_user.name,
        }


    async def login(self, userAccount: str, password: str):
        # 1. 유저 조회
        user = await self.user_repo.get_user_by_username(userAccount)

        # 2. 해시 검증 (저장된 해시와 입력한 평문 비밀번호 비교)
        if not user or not verify_password(password, user.password_hash) or not await self.user_repo.is_active(user.user_id):
            return None # 인증 실패

        # 3. 인증 성공 시, 해당 유저의 DB ID번호(PK)를 넣어 토큰 생성
        token = create_access_token(user_id=user.user_id, auth_version=user.auth_version)
        return token

    async def profile(self, user_id, changes=None):
        if changes:
            if changes.get("birth") is not None:
                changes["birth"] = datetime.combine(changes["birth"], time.min, timezone.utc)
            user = await self.user_repo.update_profile(user_id, changes)
        else:
            user = await self.user_repo.profile(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="회원 정보를 찾을 수 없습니다.")
        return {"result": {"id": user.login_id, "name": user.name,
                           "birth": user.birth.date() if user.birth else None,
                           "gender": user.gender}}

    async def withdraw(self, user_id):
        await self.user_repo.withdraw(user_id)

    async def restore(self, account, password):
        user = await self.user_repo.get_user_by_username(account)
        if not user or not verify_password(password, user.password_hash):
            raise PermissionError("아이디 또는 비밀번호를 확인해 주세요.")
        if not await self.user_repo.restore(user.user_id):
            raise ConsentConflict("복구할 수 있는 탈퇴 신청이 없거나 30일 기한이 지났습니다.")

    async def purge_expired_users(self):
        deleted_count = 0
        for row in await self.user_repo.expired_user_ids():
            try:
                async with self.user_repo.expired_account(row["user_id"]) as candidate:
                    if candidate is None:
                        continue
                    tx, image_urls = candidate
                    for url in image_urls:
                        await storage.delete_image(url)
                    await self.user_repo.delete_expired_account(tx, row["user_id"])
                deleted_count += 1
            except Exception:
                logging.getLogger(__name__).exception("탈퇴 계정 삭제 실패. 다음 실행에서 재시도합니다.")
        await self.user_repo.cleanup_retention()
        return deleted_count
