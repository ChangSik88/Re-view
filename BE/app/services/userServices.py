from app.repositories.userRepositories import UserRepository
from fastapi import HTTPException
from app.core.security import create_access_token
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
    

    async def login(self, userAccount: str, password: str):
        # 1. 유저 조회
        user = await self.user_repo.get_user_by_username(userAccount)
        
        # 2. 초간단 인증 (실무에선 해시 암호화를 쓰지만, 여기선 직관적으로 비교만 합니다)
        if not user or user.password != password:
            return None # 인증 실패
            
        # 3. 인증 성공 시, 해당 유저의 DB ID번호(PK)를 넣어 토큰 생성
        token = create_access_token(user_id=user.user_id)
        return token