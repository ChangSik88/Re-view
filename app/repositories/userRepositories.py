from app.core.db import db
from prisma.models import User

class UserRepository:
    async def find_by_id(self, user_id: str) -> User:
        # 특정 ID를 가진 유저가 있는지 조회
        return await db.user.find_first(where={'id': user_id})

    async def create_user(self, data: dict) -> User:
        # 유저 데이터를 실제로 DB에 저장
        return await db.user.create(data=data)