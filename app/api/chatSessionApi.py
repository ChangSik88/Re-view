from fastapi import APIRouter, HTTPException,Depends
from app.services.chatSessionService import ChatSessionService
from app.schemas.chatSessionSchema import ChatSessionResponse,SingleSessionResponse
from typing import Optional
from app.api.dependencies import get_current_user_id

router = APIRouter()
chat_service = ChatSessionService()

@router.get("/session/all", response_model=ChatSessionResponse)
async def get_all_chat_sessions(
    user_id:int=Depends(get_current_user_id),
    is_marked: Optional[bool] = None):
    try:
        # 서비스 계층에 데이터 요청
        sessions = await chat_service.get_user_sessions(user_id,is_marked)
        
        # Schema에 정의한 껍데기 규격에 맞춰서 반환
        return {"message": "채팅 세션 목록 조회 성공", "result": sessions}
        
    except Exception as e:
        # 에러 발생 시 500 에러와 함께 원인 반환
        raise HTTPException(status_code=500, detail=f"세션 조회 중 오류 발생: {str(e)}")
    

@router.get("/session/single/{room_id}", response_model=SingleSessionResponse)
async def get_single_session(room_id: int, user_id: int=Depends(get_current_user_id) ):
    try:
        # 서비스 계층 호출
        session = await chat_service.get_single_session(user_id, room_id)
        
        return {"message": "세션 상세 조회 성공", "result": session}
        
    except ValueError as e:
        # 서비스 계층에서 던진 ValueError(데이터 없음)는 404 Not Found로 처리
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"상세 조회 중 오류 발생: {str(e)}")