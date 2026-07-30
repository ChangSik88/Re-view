from app.repositories.userRepositories import UserRepository
from fastapi import HTTPException
from app.core.security import create_access_token, hash_password, verify_password
class UserService:
    def __init__(self):
        self.user_repo = UserRepository()

    async def register_user(self, user_data: dict):
        # 1. 비즈니스 로직: 아이디 중복 체크
        existing_user = await self.user_repo.find_by_id(user_data['id'])
        if existing_user:
            raise HTTPException(status_code=400, detail="이미 있는 아이디입니다.")

        # 2. 비밀번호를 해시로 변환한 뒤 저장 (평문 저장 금지)
        # DB 컬럼명(login_id/password_hash)이 API 요청 필드명(id/password)과 다르므로 매핑
        create_data = {
            "login_id": user_data["id"],
            "password_hash": hash_password(user_data["password"]),
            "name": user_data["name"],
            "birth": user_data["birth"],
            "gender": user_data["gender"],
        }
        created_user = await self.user_repo.create_user(create_data)
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
        if not user or not verify_password(password, user.password_hash):
            return None # 인증 실패

        # 3. 인증 성공 시, 해당 유저의 DB ID번호(PK)를 넣어 토큰 생성
        token = create_access_token(user_id=user.user_id)
        return token