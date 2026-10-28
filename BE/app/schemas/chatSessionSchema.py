
from pydantic import BaseModel,Field, model_validator
from typing import List, Optional
from datetime import datetime

#유저의 전체 세션 데이터
class RecordLocation(BaseModel):
    place_name: Optional[str] = Field(default=None, max_length=100)
    latitude: Optional[float] = Field(default=None, ge=-90, le=90, allow_inf_nan=False)
    longitude: Optional[float] = Field(default=None, ge=-180, le=180, allow_inf_nan=False)

    @model_validator(mode='after')
    def validate_location(self):
        values = (self.place_name, self.latitude, self.longitude)
        if all(value is None for value in values):
            return self
        if any(value is None for value in values) or not self.place_name.strip():
            raise ValueError('장소 이름과 위도, 경도를 함께 입력해 주세요.')
        self.place_name = self.place_name.strip()
        return self

class ChatSessionData(RecordLocation):
    created_at: Optional[datetime] = None
    room_id: int        # DB 설계에 따라 str일 수도 있으니 확인해 주세요!
    title: Optional[str]
    content: Optional[str]
    tags: Optional[str] # 태그가 null일 수 있다면 Optional
    is_marked: Optional[bool]
    updated_at: Optional[datetime]
    routine_type: Optional[str]
    image_url: Optional[str] = None

    class Config:
        from_attributes = True
class ChatSessionResponse(BaseModel):
    message:str
    result:List[ChatSessionData]

#단일 세션 데이터
class SingleSessionData(RecordLocation):
    routine_type: Optional[str] = None
    tags: Optional[str] = None
    room_id: int
    # 일기 작성 전에는 DB에서 NULL이다(schema.prisma의 ChatRoom.title/content는 String?).
    # str로 두면 응답 검증이 터져 상세 조회가 500이 된다.
    title: Optional[str]
    content: Optional[str]
    created_at:Optional[datetime]
    updated_at: Optional[datetime]
    image_url: Optional[str] = None
    is_marked: Optional[bool] = None
    class Config:
        from_attributes = True

class SingleSessionResponse(BaseModel):
    message: str
    result: SingleSessionData

class ChatMessageData(BaseModel):
    user_id: int
    text: str = Field(description="채팅 메시지 내용")
    is_me: bool = Field(description="유저가 보낸 메시지인지(True) AI가 보낸 메시지인지(False)")
    created_at: datetime

    class Config:
        from_attributes = True

# 💡 API 최종 반환 껍데기
class ChatHistoryResponse(BaseModel):
    message: str
    result: List[ChatMessageData]