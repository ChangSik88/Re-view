from pydantic import BaseModel, Field
from typing import List, Optional

#요청 형태
class ChatMessageRequest(BaseModel):
    session_id: int # 어떤 채팅방에서 온 메시지인지
    message: str    # 유저가 보낸 채팅 내용
    
class SessionCreateRequest(BaseModel):
    routine_type: str=Field(description= "Morning 또는 Night")


#출력 형태 구조화
class AIAnalysisResponse(BaseModel):
    theme: str = Field(description="꿈의 핵심 주제")
    vibe: str = Field(description="꿈의 전반적인 분위기")
    #동적 생성. 핵심 감정 키워드 3개를 대화에서 추출
    suggested_feelings: List[str] = Field(description="유저가 느꼈을 법한 핵심 감정 키워드 3개")
    ai_reply: str = Field(description="유저에게 건네는 AI의 공감 멘트 및 다음 질문")

# --- [3. 서버 -> 프론트엔드 (응답 스키마)] ---
class ChatMessageResponse(BaseModel):
    session_id: int
    analysis: Optional[AIAnalysisResponse] = None # 화면에 그려줄 UI 데이터 (주제, 분위기, 추천 감정)


class DiaryGenerationResponse(BaseModel):
    title: str = Field(description="일기의 제목")
    content: str = Field(description="문학적이고 감성적인 일기 본문 (3~4문단)")
    tags: List[str] = Field(description="일기를 대표하는 감성 해시태그 3개")
    image_prompt:str=Field(description="FLUX 이미지 생성 AI에 넣을 영어프롬프트")

# [추가] 프론트엔드에서 일기 생성을 요청할 때 쓸 스키마
class DiaryRequest(BaseModel):
    session_id: int
    selected_keywords: List[str] = []

class SessionMarkRequest(BaseModel):
    is_marked: bool