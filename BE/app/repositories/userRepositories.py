from datetime import datetime, timedelta, timezone

from app.core.db import db
from app.core import storage
from prisma.models import User

class UserRepository:
    async def find_by_id(self, account_id: str) -> User:
        # 특정 ID를 가진 유저가 있는지 조회
        return await db.user.find_first(where={'login_id': account_id})

    async def create_user(self, data: dict) -> User:
        # 유저 데이터를 실제로 DB에 저장
        return await db.user.create(data=data)
    
    async def get_user_by_username(self, userAccount: str):
        # Prisma를 이용해 아이디로 유저를 검색합니다.
        # (테이블 스키마에 따라 db.user 부분은 달라질 수 있습니다)
        return await db.user.find_unique(
            where={"login_id": userAccount}
        )

    async def is_active(self, user_id: int):
        return await db.user.find_first(where={
            "user_id": user_id, "UserWithdrawal": {"none": {}}
        }) is not None

    async def profile(self, user_id: int):
        return await db.user.find_unique(where={"user_id": user_id})

    async def update_profile(self, user_id: int, data: dict):
        return await db.user.update(where={"user_id": user_id}, data=data)

    async def withdraw(self, user_id: int):
        async with db.tx() as tx:
            await tx.query_raw('SELECT user_id FROM users WHERE user_id = $1 FOR UPDATE', user_id)
            existing = await tx.userwithdrawal.find_first(where={"user_id": user_id})
            if not existing:
                withdrawn_at = datetime.now(timezone.utc)
                await tx.userwithdrawal.create(data={
                    "user_id": user_id,
                    "withdrawn_at": withdrawn_at,
                    "purge_scheduled_at": withdrawn_at + timedelta(days=30),
                })

    async def purge_expired_users(self) -> int:
        # 이전 버전에서 탈퇴한 계정에도 원래 탈퇴일 기준으로 정책을 적용한다.
        await db.execute_raw('''
            UPDATE user_withdrawals
            SET purge_scheduled_at = withdrawn_at + INTERVAL '30 days'
            WHERE purge_scheduled_at IS NULL
        ''')
        expired_users = await db.query_raw('''
            SELECT DISTINCT user_id FROM user_withdrawals
            WHERE purge_scheduled_at <= CURRENT_TIMESTAMP
        ''')
        deleted_count = 0
        for user in expired_users:
            user_id = user["user_id"]
            async with db.tx(timeout=timedelta(seconds=60)) as tx:
                # 여러 서버가 동시에 시작해도 같은 계정을 중복 처리하지 않는다.
                locked = await tx.query_raw('''
                    SELECT user_id FROM users
                    WHERE user_id = $1 AND EXISTS (
                        SELECT 1 FROM user_withdrawals
                        WHERE user_withdrawals.user_id = users.user_id
                          AND purge_scheduled_at <= CURRENT_TIMESTAMP
                    )
                    FOR UPDATE SKIP LOCKED
                ''', user_id)
                if not locked:
                    continue
                images = await tx.query_raw('''
                    SELECT image_url FROM chat_images
                    JOIN chat_rooms USING (room_id) WHERE user_id = $1
                ''', user_id)
                # 파일 삭제가 실패하면 DB 기록을 보존해 다음 시작 때 재시도한다.
                for image in images:
                    await storage.delete_image(image["image_url"])
                # 구매를 참조하는 Restrict 관계부터 삭제한다.
                await tx.execute_raw('''
                    DELETE FROM payments WHERE purchase_id IN (
                        SELECT purchase_id FROM purchases WHERE user_id = $1
                    )
                ''', user_id)
                await tx.execute_raw('''
                    DELETE FROM shipments WHERE purchase_id IN (
                        SELECT purchase_id FROM purchases WHERE user_id = $1
                    ) OR address_id IN (
                        SELECT address_id FROM user_addresses WHERE user_id = $1
                    )
                ''', user_id)
                await tx.execute_raw('''
                    DELETE FROM diary_entries WHERE purchase_id IN (
                        SELECT purchase_id FROM purchases WHERE user_id = $1
                    )
                ''', user_id)
                await tx.purchase.delete_many(where={"user_id": user_id})
                await tx.customerinquiry.delete_many(where={"user_id": user_id})
                await tx.userwithdrawal.delete_many(where={"user_id": user_id})
                # 나머지 사용자 데이터는 기존 FK의 Cascade로 함께 삭제된다.
                await tx.user.delete(where={"user_id": user_id})
            deleted_count += 1
        return deleted_count
