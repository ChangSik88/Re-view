from app.core.db import db
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
                await tx.userwithdrawal.create(data={"user_id": user_id})
