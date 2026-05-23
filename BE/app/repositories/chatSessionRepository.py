from app.core.db import db 
from typing import Optional
# 대시보드 구성에 필요한 정보 호출
class ChatSessionRepository:
    async def get_all_sessions_by_user_id(self, user_id: int, is_marked: Optional[bool] = None):
        where_filter = {"user_id":user_id}
        if is_marked is not None:
            where_filter["is_marked"] = is_marked
        
        # 순수하게 DB에서 데이터를 가져오는 역할만 합니다.
        sessions = await db.chatsession.find_many(
            where=where_filter,
            order={
                "updated_at": "desc" # 최신순 정렬
            }
        )
        return sessions
    
    async def get_one_session_by_id(self, user_id: int, room_id: int):
            # find_first를 사용하여 조건에 맞는 단 하나의 데이터만 가져옵니다.
            session = await db.chatsession.find_first(
                where={
                    "room_id": room_id,
                    "user_id": user_id  # 내 세션이 맞는지 확인하는 필수 보안 장치!
                }
            )
            return session