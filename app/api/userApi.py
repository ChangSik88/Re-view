from fastapi import APIRouter
from app.services.userServices import UserService
from app.schemas.userSchema import UserCreateBody,UserResponse # Schema 폴더에 정의할 모델


router = APIRouter()
user_service = UserService()

@router.post("/signup",response_model=UserResponse)
async def signup(user: UserCreateBody):
    # 서비스 계층에 데이터 전달
    result = await user_service.register_user(user.model_dump())
    return {"message": "회원가입 완료", "result": result}