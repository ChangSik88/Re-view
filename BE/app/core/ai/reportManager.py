# 💡 OpenAI 대신 최신 Google Generative AI 패키지 임포트
from langchain_google_genai import ChatGoogleGenerativeAI
# 💡 구버전(langchain.prompts) 대신 최신 코어 모듈 임포트
from langchain_core.prompts import PromptTemplate

class ReportManager:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-3.1-flash-lite",
            temperature=0.7
        )

    async def generate_insight(self, daily_summary: str, top_tags: str) -> str:
        prompt = PromptTemplate(
                    input_variables=["daily_summary", "top_tags"],
                    template="""당신은 사용자의 마음을 읽어주는 다정하고 통찰력 있는 심리 상담가입니다.
                    다음은 최근 기록을 날짜순으로 정리한 자료입니다. 각 줄은 하루치이며, 아침(꿈)과 밤(하루 기록) 각각의 분류 범주와 태그를 담고 있습니다.

                    {daily_summary}

                    최근 가장 자주 등장한 태그: {top_tags}

                    [작성 지침 - 반드시 엄수할 것]
                    1. 분량 제한: 전체 답변을 반드시 3~4문장(줄) 이내로 아주 짧게 작성하세요.
                    2. 근거 기반: 위 자료에 적힌 범주·태그만 근거로 삼으세요. 자료에 없는 사건이나 감정을 지어내지 마세요.
                    3. 같은 날 아침 범주와 밤 범주가 같으면 그 연관성을 짚어주세요. 다른 날은 억지로 엮지 마세요.
                    4. 말투 및 구조: 친근하고 다정한 대화체(~해요, ~네요)를 사용하며, 아래의 흐름을 따라 자연스럽게 구성하세요.
                    - 도입: 최근 가장 자주 등장한 태그나 범주로 전반적인 흐름 짚어주기
                    - 의미: 그 흐름이 뜻하는 심리적 의미를 가볍게 설명
                    - 마무리: 사용자의 현실 상황에 대한 따뜻한 공감, 질문 또는 격려"""
                )

        # LangChain v0.1.0 이상 권장 방식 (LCEL 파이프라인)
        chain = prompt | self.llm
        response = await chain.ainvoke({"daily_summary": daily_summary, "top_tags": top_tags})

        # Gemini는 content를 [{"type": "text", "text": ...}] 형태의 블록 리스트로 돌려준다.
        # 리스트 그대로 넘기면 weekly_content(String?) 저장이 타입 오류로 깨진다.
        if isinstance(response.content, list):
            return "".join(
                block.get("text", "")
                for block in response.content
                if isinstance(block, dict)
            )

        return response.content
