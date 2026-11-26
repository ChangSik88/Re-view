from pydantic import BaseModel, Field
from typing import List, Optional

#요청 형태
class ChatMessageRequest(BaseModel):
    session_id: int # 어떤 채팅방에서 온 메시지인지
    message: str    # 유저가 보낸 채팅 내용
    
class SessionCreateRequest(BaseModel):
    routine_type: str=Field(description= "Morning 또는 Night")


#출력 형태 구조화
class StoryDetailsResponse(BaseModel):
    place: str = ""
    characters: List[str] = Field(default_factory=list)
    emotions: str = ""
    situation: str = ""
    memo: str = ""


class AIAnalysisResponse(BaseModel):
    story_details: StoryDetailsResponse = Field(default_factory=StoryDetailsResponse)
    theme: str = Field(description="꿈의 핵심 주제")
    vibe: str = Field(description="꿈의 전반적인 분위기")
    #동적 생성. 핵심 감정 키워드 3개를 대화에서 추출
    suggested_feelings: List[str] = Field(description="유저가 느꼈을 법한 핵심 감정 키워드 3개")
    ai_reply: str = Field(description="유저에게 건네는 AI의 공감 멘트 및 다음 질문")
    # 기본값을 둔 이유: 이 스키마는 운영 중인 /chatting/message도 공유한다.
    # 필수로 두면 LLM이 이 필드를 빠뜨리는 순간 파싱이 실패해 앱 채팅까지 죽는다.
    dream_category: str = Field(default="기타", description="아래 목록 중 정확히 하나: 쫓김, 이빨, 똥, 돼지, 조상님, 뱀, 불, 물, 높은곳, 피, 시험, 죽음, 기타")

class NightAnalysisResponse(AIAnalysisResponse):
    # 부모의 해몽 카테고리 목록이 나이트 출력 형식 안내에 섞이지 않도록 덮어쓴다.
    dream_category: str = Field(default="기타", description="나이트루틴에서는 항상 '기타'")
    theme: str = Field(default="", description="사용자가 말한 하루 사건의 주제. 불명확하면 빈 문자열")
    vibe: str = Field(default="", description="사용자가 직접 표현한 분위기. 불명확하면 빈 문자열")
    suggested_feelings: List[str] = Field(default_factory=list, description="사용자가 표현한 감정만. 없으면 빈 목록이며 개수를 채우지 않음")
    ai_reply: str = Field(description="현재 사건에 대한 짧은 반응과 필요할 때만 미확인 내용 하나를 묻는 1~3문장. 질문은 최대 하나")


# --- [3. 서버 -> 프론트엔드 (응답 스키마)] ---
class ChatMessageResponse(BaseModel):
    session_id: int
    analysis: Optional[AIAnalysisResponse] = None # 화면에 그려줄 UI 데이터 (주제, 분위기, 추천 감정)


class DiaryGenerationResponse(BaseModel):
    title: str = Field(description="일기의 제목")
    content: str = Field(description="문학적이고 감성적인 일기 본문 (3~4문단)")
    tags: List[str] = Field(description="일기를 대표하는 감성 해시태그 3개")
    image_prompt:str=Field(description="이미지 생성 AI에 넣을 영어 프롬프트")
    # 기본값을 둔 이유: 필수로 두면 LLM이 이 필드를 빠뜨리는 순간 파싱이 실패해 일기 생성 전체가 죽는다.
    dream_category: str = Field(default="행동·상황", description="아래 9개 카테고리 중 정확히 하나: 동물, 사물·재물, 삶의 변화, 신체·생리, 인물·관계, 자연·환경, 장소·공간, 초자연, 행동·상황")

# [추가] 프론트엔드에서 일기 생성을 요청할 때 쓸 스키마
class DiaryRequest(BaseModel):
    session_id: int
    selected_keywords: List[str] = []

class SessionMarkRequest(BaseModel):
    is_marked: bool

class SessionLocationRequest(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    place_name: Optional[str] = Field(default=None, max_length=100)
