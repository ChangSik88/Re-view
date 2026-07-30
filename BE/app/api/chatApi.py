from fastapi import APIRouter, Depends, HTTPException
from app.schemas.chatSchema import ChatMessageRequest, ChatMessageResponse, DiaryGenerationResponse, DiaryRequest,SessionCreateRequest,SessionMarkRequest
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
async def send_message(request: ChatMessageRequest, user_id: int = Depends(get_current_user_id)):
    # 토큰의 user_id로 방 소유권을 검증한 뒤 서비스 계층으로 넘깁니다.
    try:
        return await chat_service.process_message(user_id, request.session_id, request.message)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))

#image_url도 함께 받기 위해서 response_model 없앰
@router.post("/diary")
async def generate_diary(request: DiaryRequest, user_id: int = Depends(get_current_user_id)):
    # 토큰의 user_id로 방 소유권을 검증한 뒤 키워드를 서비스로 전송
    try:
        return await chat_service.create_diary(user_id, request.session_id, request.selected_keywords)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))

# 4. 즐겨찾기 상태 명시적 설정 (body로 원하는 최종 상태를 지정)
@router.patch("/session/{session_id}/mark")
async def set_session_mark(session_id: int, request: SessionMarkRequest, user_id: int = Depends(get_current_user_id)):
    try:
        is_marked = await chat_service.set_marked(user_id, session_id, request.is_marked)
        return {"message": "즐겨찾기 상태 변경 완료", "room_id": session_id, "is_marked": is_marked}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))

# 5. 채팅 세션(꿈 일기) 삭제
@router.delete("/session/{session_id}")
async def delete_session(session_id: int, user_id: int = Depends(get_current_user_id)):
    try:
        await chat_service.delete_session(user_id, session_id)
        return {"message": "채팅방 삭제 완료", "room_id": session_id}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
