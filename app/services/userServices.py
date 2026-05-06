from app.repositories.userRepositories import UserRepository
from fastapi import HTTPException

class UserService:
    def __init__(self):
        self.user_repo = UserRepository()

    async def register_user(self, user_data: dict):
        # 1. 비즈니스 로직: 아이디 중복 체크
        existing_user = await self.user_repo.find_by_id(user_data['id'])
        if existing_user:
            raise HTTPException(status_code=400, detail="이미 있는 아이디입니다.")
        
        # 2. 저장
        return await self.user_repo.create_user(user_data)