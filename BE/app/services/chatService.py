from app.repositories.chatRepository import ChatRepository
from app.schemas.chatSchema import AIAnalysisResponse
from app.core.ai.langchainManager import analyze_dream_chat, generate_diary_content, generate_vector_embedding
from app.core.ai.imageManager import ImageManager
from typing import List
import uuid
import os


class ChatService:
    def __init__(self):
        self.chat_repo = ChatRepository()
        self.image_manager=ImageManager()
        

    # 채팅방 생성 로직
    async def create_new_chat(self, user_id: int,routine_type:str):
        return await self.chat_repo.create_session(user_id, routine_type)

    # 즐겨찾기 상태 설정 (명시적 설정 — 토글 아님)
    async def set_marked(self, user_id: int, room_id: int, is_marked: bool) -> bool:
        await self._get_owned_session(user_id, room_id)
        session = await self.chat_repo.set_marked(room_id, is_marked)
        return session.is_marked

    # 방 소유권 검증 공통 로직
    async def _get_owned_session(self, user_id: int, room_id: int):
        session = await self.chat_repo.get_session(room_id)
        if not session:
            raise ValueError("채팅방을 찾을 수 없습니다.")
        if session.user_id != user_id:
            raise PermissionError("해당 채팅방에 접근할 권한이 없습니다.")
        return session

    # 핵심 대화 처리 로직
    async def process_message(self, user_id: int, room_id: int, user_message: str):
        # 방 소유권 검증: 존재하지 않거나 남의 방이면 차단
        session = await self._get_owned_session(user_id, room_id)
        routine_type = session.routine_type

        # 유저가 보낸 메시지를 DB에 저장
        await self.chat_repo.save_message(room_id, "USER", user_message)

        # 2. 과거 대화 기록을 DB에서 꺼내옵니다.
        history = await self.chat_repo.get_chat_history(room_id)

        formatted_history = "\n".join([f"{msg.role}: {msg.content}" for msg in history])

        # 3. LangChain을 이용해 AI에게 대화 기록과 새 메시지를 던지고 분석을 요청합니다.
        # (아래는 LangChain 구조화된 출력의 뼈대 예시입니다. 실제 LLM 연동 코드로 대체됩니다.)

        ai_result = await analyze_dream_chat(
            history=formatted_history,
            new_message=user_message,
            routine_type=routine_type
        )


        # 4. AI가 생성한 대답(ai_reply)을 DB에 저장합니다.
        await self.chat_repo.save_message(room_id, "AI", ai_result.ai_reply)

        # 5. 프론트엔드로 전달할 최종 데이터 조립 (대답 + UI 구성용 데이터)
        return {
            "session_id": room_id,
            "analysis": ai_result
        }

    async def create_diary(self, user_id: int, room_id: int, selected_keywords: List[str]):
        # 방 소유권 검증: 존재하지 않거나 남의 방이면 차단
        session = await self._get_owned_session(user_id, room_id)
        routine_type = session.routine_type

        history_records = await self.chat_repo.get_chat_history(room_id)
        formatted_history = "\n".join([f"{msg.role}: {msg.content}" for msg in history_records])

        # AI 함수에 키워드 리스트를 함께 넘겨주기
        diary_result = await generate_diary_content(
            history=formatted_history,
            selected_keywords=selected_keywords,
            routine_type=routine_type)

        # Vector 변환 (제목과 내용을 합쳐서 의미를 뭉칩니다)
        text_to_embed = f"제목: {diary_result.title}\n내용: {diary_result.content}"
        vector_data = await generate_vector_embedding(text_to_embed)

        # title/tags는 DB 컬럼이 VarChar(50)이라 AI 생성 텍스트가 넘치면 저장 시 예외 발생 →
        # 여기서 미리 잘라 트랜잭션 실패(및 LLM 호출 낭비)를 막는다.
        title = diary_result.title[:50]
        tags_str = ", ".join(diary_result.tags)[:50]

        # 생성된 모든 데이터를 ChatSession DB에 저장
        await self.chat_repo.update_session_with_diary(
            room_id=room_id,
            title=title,
            content=diary_result.content,
            tags=tags_str,
            vector=vector_data
        )

        image_url = await self._generate_and_save_image(room_id, diary_result.image_prompt)

        return {
        "title": diary_result.title,
        "content": diary_result.content,
        "tags": diary_result.tags,
        "image_url": image_url
    }
    
    async def _generate_and_save_image(self, room_id: int, image_prompt: str):
        try:
            # AI 이미지 생성
            image = await self.image_manager.generate_flux_image(image_prompt)

            # 파일 저장 경로 설정 (static/images/UUID.png)
            file_name = f"{uuid.uuid4()}.png"
            file_dir = "app/static/images"
            if not os.path.exists(file_dir):
                os.makedirs(file_dir)

            save_path = os.path.join(file_dir, file_name)
            image.save(save_path)

            # 서버 베이스 URL 기반의 이미지 URL 생성 (.env의 SERVER_BASE_URL 사용)
            base_url = os.getenv("SERVER_BASE_URL", "http://13.209.97.107:8000").rstrip("/")
            image_url = f"{base_url}/static/images/{file_name}"

            # 4. 이미지 URL DB 저장 (Repository 호출)
            await self.chat_repo.save_chat_image(room_id, image_url)
            
            return image_url
        except Exception as e:
            print(f"이미지 생성 중 오류 발생: {e}")
            return None