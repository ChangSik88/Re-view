from fastapi import APIRouter
from pydantic import BaseModel
from app.schemas.chatSchema import ChatMessageRequest, ChatMessageResponse, DiaryGenerationResponse, DiaryRequest
from app.services.chatService import ChatService
from pydantic import Field

router = APIRouter()
chat_service = ChatService()

# 임시: 토큰이 없으니 프론트에서 유저 ID를 직접 쏴주기 위한 스키마
class SessionCreateRequest(BaseModel):
    user_id: int
    routine_type: str=Field(description= "Morning 또는 Night")

# 1. 새로운 채팅방 만들기 (채팅 탭 진입 시 호출)
@router.post("/session")
async def create_session(request: SessionCreateRequest):
    # 안드로이드에서 보낸 user_id(예: "abcd")로 방을 만듭니다.
    session = await chat_service.create_new_chat(request.user_id,request.routine_type)
    return {"message": "채팅방 생성 완료", "session_id": session.room_id, "routine_type": session.routine_type}

# 2. 메시지 보내기 & AI 응답 받기 (채팅 칠 때마다 호출)
@router.post("/message", response_model=ChatMessageResponse)
async def send_message(request: ChatMessageRequest):
    # 토큰 검사 없이 바로 서비스 계층으로 넘깁니다.
    # request 안에 이미 몇 번 방(session_id)인지 적혀있어서 유저 정보가 없어도 돌아갑니다.
    result = await chat_service.process_message(request.session_id, request.message)
    return result

#image_url도 함께 받기 위해서 response_model 없앰
@router.post("/diary")
async def generate_diary(request: DiaryRequest):
    # 키워드도 서비스로 전송
    result = await chat_service.create_diary(request.session_id, request.selected_keywords)
    return result

