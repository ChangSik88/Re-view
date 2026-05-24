from pydantic import BaseModel, Field
from typing import Optional
from pydantic import BaseModel, field_validator
from datetime import date, datetime, timezone

# 안드로이드에서 회원가입 시 보내줄 데이터 규격
class UserCreateBody(BaseModel):
    id: str = Field(..., max_length=30, description="사용자 아이디")
    password: str = Field(..., max_length=30, description="비밀번호")
    name: str = Field(..., max_length=30)
    birth: Optional[datetime]
    @field_validator('birth', mode='before') #Prisma가 date때문에 오류 내기 전에 가져오기
    def assemble_date(cls, v): #v는 들어온 데이터
        if isinstance(v, str): #들어온 데이터가 String이면
            v = date.fromisoformat(v) # 문자열을 date 객체로
        if isinstance(v, date) and not isinstance(v, datetime): 
            return datetime(v.year, v.month, v.day, tzinfo=timezone.utc) #datetime으로 리턴
        return v
    gender: str = Field(..., pattern="^(male|female)$") # 특정 값만 허용하도록 검증 가능

# 회원가입 성공 후 안드로이드에 다시 보내줄 데이터 규격
class UserData(BaseModel):
    user_id: int
    id: str
    name: str
    password: str
    
    class Config:
        from_attributes = True # Prisma 모델 객체를 자동으로 Schema로 변환해줌

class UserResponse(BaseModel):
    message: str
    result: UserData

class LoginRequest(BaseModel):
    userAccount: str
    password: str