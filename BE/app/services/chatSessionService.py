from app.repositories.chatSessionRepository import ChatSessionRepository
from typing import Optional 

class ChatSessionService:
    def __init__(self):
        # 레포지토리 객체를 생성해서 가지고 있습니다.
        self.chat_session_repository = ChatSessionRepository()
        

    async def get_user_sessions(self, user_id: int,is_marked: Optional[bool] = None):
        raw_sessions = await self.chat_session_repository.get_all_sessions_by_user_id(user_id,is_marked)
        #데이터 가공을 위한 리스트
        processed_sessions = []
        for session in raw_sessions:
           # ChatImage 데이터가 존재할 때만 image_url을 꺼내고, 빈 값이면 None을 할당합니다.
            image_url = getattr(session, 'ChatImage', None) # 혹시 속성 자체가 없을 때를 대비한 2중 안전장치
            extracted_url = next((img.image_url for img in image_url),None) #1:1 관계라 스키마 재정의 해야하는데 시간 없으니까 걍 둠
            #TODO: 스키마 구조 리스트 형태가 아닌 1:1 관계인점 참고해서 수정하기
                
            processed_sessions.append({
                "room_id": session.room_id,
                "title": session.title,
                "content": session.content,
                "tags": session.tags,
                "routine_type": session.routine_type,
                "is_marked": session.is_marked,
                "updated_at": str(session.updated_at),
                "image_url": extracted_url  # 추출된 진짜 주소(또는 None)가 프론트로 전달됨
            })
        return processed_sessions
    
    async def get_single_session(self, user_id: int, room_id: int):
            session = await self.chat_session_repository.get_one_session_by_id(user_id, room_id)
            
            # 만약 없는 방 번호를 요청했거나 남의 방을 요청했다면 session은 None이 됩니다.
            if not session:
                raise ValueError("세션을 찾을 수 없거나 접근 권한이 없습니다.")
            image_url = getattr(session, 'ChatImage', None)
            extracted_url = next((img.image_url for img in image_url),None)

            return {
                "room_id": session.room_id,
                "title": session.title,
                "content": session.content,
                "created_at":session.created_at,
                "updated_at": str(session.updated_at),
                "image_url": extracted_url
            }
    
    
    async def get_chat_history(self, user_id: int, room_id: int):
        # 1. 보안 검사: 해당 채팅방이 존재하는지, 그리고 이 유저의 방이 맞는지 확인
        session = await self.chat_session_repository.get_one_session_by_id(user_id,room_id)
        
        if not session:
            raise ValueError("해당 채팅방을 찾을 수 없습니다.")

        # 2. 메시지 내역 불러오기
        raw_messages = await self.chat_session_repository.get_messages_by_room_id(room_id)

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