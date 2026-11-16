from datetime import date
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, StrictBool, field_validator

from app.schemas.consentSchema import ConsentChanges

# 안드로이드에서 회원가입 시 보내줄 데이터 규격
class UserCreateBody(ConsentChanges):
    id: str = Field(min_length=1, max_length=30, pattern=r"^\S+$")
    password: str = Field(min_length=1, max_length=30)
    name: str = Field(min_length=1, max_length=30)
    age_over_14_confirmed: StrictBool

    @field_validator("name")
    @classmethod
    def valid_signup_name(cls, value):
        if not value.strip():
            raise ValueError("이름을 입력해 주세요.")
        return value.strip()

# 회원가입 성공 후 안드로이드에 다시 보내줄 데이터 규격
class UserData(BaseModel):
    user_id: int
    id: str
    name: str

    model_config = ConfigDict(from_attributes=True)

class UserResponse(BaseModel):
    message: str
    result: UserData

class LoginRequest(BaseModel):
    userAccount: str
    password: str


class RestoreRequest(BaseModel):
    userAccount: str = Field(min_length=1, max_length=30)
    password: str = Field(min_length=1, max_length=30)


class RestoreResponse(BaseModel):
    message: str

class ProfilePatch(BaseModel):
    model_config = {"extra": "forbid"}
    name: Optional[str] = Field(default=None, max_length=30)
    # 이전 응답 필드는 유지하되, 새 생년월일·성별 수집은 허용하지 않는다.
    birth: None = None
    gender: None = None

    @field_validator("name")
    @classmethod
    def valid_name(cls, value):
        if value is None or not value.strip():
            raise ValueError("이름을 입력해 주세요.")
        return value.strip()

class ProfileData(BaseModel):
    id: str
    name: str
    birth: Optional[date]
    gender: Optional[str]

class ProfileResponse(BaseModel):
    result: ProfileData
