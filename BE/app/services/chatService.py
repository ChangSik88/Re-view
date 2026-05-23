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

    # 핵심 대화 처리 로직
    async def process_message(self, session_id: int, user_message: str):
        routine_type= await self.chat_repo.get_routine_type(session_id)
    
        # 유저가 보낸 메시지를 DB에 저장
        await self.chat_repo.save_message(session_id, "USER", user_message)

        # 2. 과거 대화 기록을 DB에서 꺼내옵니다.
        history = await self.chat_repo.get_chat_history(session_id)

        formatted_history = "\n".join([f"{msg.role}: {msg.content}" for msg in history])
        
        # 3. LangChain을 이용해 AI에게 대화 기록과 새 메시지를 던지고 분석을 요청합니다.
        # (아래는 LangChain 구조화된 출력의 뼈대 예시입니다. 실제 LLM 연동 코드로 대체됩니다.)

        ai_result = await analyze_dream_chat(
            history=formatted_history, 
            new_message=user_message,
            routine_type=routine_type
        )
        

        # 4. AI가 생성한 대답(ai_reply)을 DB에 저장합니다.
        await self.chat_repo.save_message(session_id, "AI", ai_result.ai_reply)

        # 5. 프론트엔드로 전달할 최종 데이터 조립 (대답 + UI 구성용 데이터)
        return {
            "session_id": session_id,
            "reply": ai_result.ai_reply,
            "analysis": ai_result
        }
    
    async def create_diary(self, session_id: int, selected_keywords: List[str]):
        routine_type = await self.chat_repo.get_routine_type(session_id)
       

        history_records = await self.chat_repo.get_chat_history(session_id)
        formatted_history = "\n".join([f"{msg.role}: {msg.content}" for msg in history_records])

        # AI 함수에 키워드 리스트를 함께 넘겨주기
        diary_result = await generate_diary_content(
            history=formatted_history, 
            selected_keywords=selected_keywords, 
            routine_type=routine_type)
        
        # Vector 변환 (제목과 내용을 합쳐서 의미를 뭉칩니다)
        text_to_embed = f"제목: {diary_result.title}\n내용: {diary_result.content}"
        vector_data = await generate_vector_embedding(text_to_embed)

        # 생성된 모든 데이터를 ChatSession DB에 저장
        await self.chat_repo.update_session_with_diary(
            session_id=session_id,
            title=diary_result.title,
            content=diary_result.content,
            tags=diary_result.tags,
            vector=vector_data
        )
        
        image_url = await self._generate_and_save_image(session_id, diary_result.image_prompt)

        return {
        "title": diary_result.title,
        "content": diary_result.content,
        "tags": diary_result.tags,
        "image_url": image_url
    }
    
    async def _generate_and_save_image(self, session_id: int, image_prompt: str):
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
            
            # 고정 IP 기반의 URL 생성
            image_url = f"http://13.209.97.107:8000/static/images/{file_name}"
            
            # 4. 이미지 URL DB 저장 (Repository 호출)
            await self.chat_repo.save_chat_image(session_id, image_url)
            
            return image_url
        except Exception as e:
            print(f"이미지 생성 중 오류 발생: {e}")
            return None