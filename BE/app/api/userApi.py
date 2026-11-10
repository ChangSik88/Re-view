from fastapi import Depends, Response
from app.api.dependencies import get_current_user_id
from app.schemas.userSchema import ProfilePatch, ProfileResponse
from fastapi import APIRouter,HTTPException
from app.services.userServices import UserService
from app.schemas.userSchema import UserCreateBody,UserResponse,LoginRequest # Schema 폴더에 정의할 모델


router = APIRouter()
user_service = UserService()

@router.post("/signup",response_model=UserResponse)
async def signup(user: UserCreateBody):
    # 서비스 계층에 데이터 전달
    result = await user_service.register_user(user.model_dump())
    return {"message": "회원가입 완료", "result": result}

@router.post("/login")
async def login_user(request: LoginRequest):
    # 서비스 로직에 아이디, 비번을 던져 토큰을 받아옵니다.
    token = await user_service.login(request.userAccount, request.password)
    
    if not token:
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 틀렸습니다.")
        
    # 안드로이드 개발자에게 JWT 토큰을 반환합니다.
    return {
        "message": "로그인 성공",
        "access_token": token,
        "token_type": "bearer"
    }

@router.get("/me", response_model=ProfileResponse)
async def my_profile(user_id: int = Depends(get_current_user_id)):
    return await user_service.profile(user_id)

@router.patch("/me", response_model=ProfileResponse)
async def edit_my_profile(body: ProfilePatch, user_id: int = Depends(get_current_user_id)):
    return await user_service.profile(user_id, body.model_dump(exclude_unset=True))

@router.delete("/me", status_code=204)
async def delete_my_account(user_id: int = Depends(get_current_user_id)):
    await user_service.withdraw(user_id)
    return Response(status_code=204)
