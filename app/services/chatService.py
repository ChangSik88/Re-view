from app.repositories.chatRepository import ChatRepository
from app.schemas.chatSchema import AIAnalysisResponse
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import PydanticOutputParser
from app.core.ai.langchainManager import analyze_dream_chat, generate_diary_content, generate_vector_embedding
from typing import List

class ChatService:
    def __init__(self):
        self.chat_repo = ChatRepository()

    # 채팅방 생성 로직
    async def create_new_chat(self, user_id: int,routine_type:str):
        return await self.chat_repo.create_session(user_id, routine_type)

    # 핵심 대화 처리 로직
    async def process_message(self, session_id: int, user_message: str):
        routine_type= await self.chat_repo.get_session(session_id)
    
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
        routine_type = await self.chat_repo.get_session(session_id)
       

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
        
        return diary_result