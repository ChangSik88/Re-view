
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

#유저의 전체 세션 데이터
class ChatSessionData(BaseModel):
    room_id: int        # DB 설계에 따라 str일 수도 있으니 확인해 주세요!
    title: Optional[str]
    content: Optional[str]
    tags: Optional[str] # 태그가 null일 수 있다면 Optional
    is_marked: Optional[bool]
    updated_at: Optional[datetime]
    routine_type: Optional[str]

    class Config:
        from_attributes = True
class ChatSessionResponse(BaseModel):
    message:str
    result:List[ChatSessionData]

#단일 세션 데이터
class SingleSessionData(BaseModel):
    room_id: int
    title: str
    content: str
    created_at:Optional[datetime]
    updated_at: Optional[datetime]
    class Config:
        from_attributes = True

class SingleSessionResponse(BaseModel):
    message: str
    result: SingleSessionData