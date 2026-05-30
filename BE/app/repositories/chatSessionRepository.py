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
            },
            include={
                 "ChatImage":True
            }
        )
        return sessions
    
    async def get_one_session_by_id(self, user_id: int, room_id: int):
            # find_first를 사용하여 조건에 맞는 단 하나의 데이터만 가져옵니다.
            session = await db.chatsession.find_first(
                where={
                    "room_id": room_id,
                    "user_id": user_id  # 내 세션이 맞는지 확인하는 필수 보안 장치!
                },
                include={
                 "ChatImage":True
            }
            )
            return session
    

    # 2. 해당 방의 모든 채팅 메시지를 과거순으로 가져오기
    async def get_messages_by_session_id(self, room_id: int):
        return await db.chatmessage.find_many( # DB 테이블 이름(chatmessage) 확인 필요
            where={"room_id": room_id},
            order={"created_at": "asc"} # 옛날 대화가 위에, 최신 대화가 아래에 오도록 오름차순(asc)
        )