from app.repositories.chatSessionRepository import ChatSessionRepository
from typing import Optional 

class ChatSessionService:
    def __init__(self):
        # 레포지토리 객체를 생성해서 가지고 있습니다.
        self.chat_session_repository = ChatSessionRepository()
        

    async def get_user_sessions(self, user_id: int,is_marked: Optional[bool] = None):
        # 만약 여기서 "삭제된 세션은 제외해라" 같은 추가 비즈니스 로직이 생기면
        # API는 건드리지 않고 이 부분에서 데이터를 가공하면 됩니다.
        sessions = await self.chat_session_repository.get_all_sessions_by_user_id(user_id,is_marked)
        return sessions
    
    async def get_single_session(self, user_id: int, room_id: int):
            session = await self.chat_session_repository.get_one_session_by_id(user_id, room_id)
            
            # 만약 없는 방 번호를 요청했거나 남의 방을 요청했다면 session은 None이 됩니다.
            if not session:
                raise ValueError("세션을 찾을 수 없거나 접근 권한이 없습니다.")
                
            return session
    
    async def get_chat_history(self, user_id: int, session_id: int):
        # 1. 보안 검사: 해당 채팅방이 존재하는지, 그리고 이 유저의 방이 맞는지 확인
        session = await self.chat_session_repository.get_one_session_by_id(user_id,session_id)
        
        if not session:
            raise ValueError("해당 채팅방을 찾을 수 없습니다.")

        # 2. 메시지 내역 불러오기
        raw_messages = await self.chat_session_repository.get_messages_by_session_id(session_id)

        # 3. 프론트엔드가 먹기 좋게 데이터 가공 (DB 모델 -> Pydantic 모델)
        history = []
        for msg in raw_messages:
            history.append({
                "user_id": user_id,
                # 💡 DB의 내용 컬럼(content)을 프론트가 원하는 text로 변환
                "text": msg.content, 
                # 💡 DB에 보낸 사람(sender)이 'user'로 저장되어 있으면 True, 아니면 False
                "is_me": msg.role == "USER", 
                "created_at": msg.created_at
            })
            
        return history