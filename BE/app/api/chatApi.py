from fastapi import APIRouter, Depends
from app.schemas.chatSchema import ChatMessageRequest, ChatMessageResponse, DiaryGenerationResponse, DiaryRequest,SessionCreateRequest
from app.services.chatService import ChatService
from app.api.dependencies import get_current_user_id

router = APIRouter()
chat_service = ChatService()


# 1. 새로운 채팅방 만들기 (채팅 탭 진입 시 호출)
@router.post("/session")
async def create_session(request: SessionCreateRequest,user_id:int=Depends(get_current_user_id)):
    # user_id로 방을 만든다
    session = await chat_service.create_new_chat(user_id,request.routine_type)
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

