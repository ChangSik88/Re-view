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

    async def generate_insight(self, dreams_text: str) -> str:
        prompt = PromptTemplate(
                    input_variables=["dreams"],
                    template="""당신은 사용자의 마음을 읽어주는 다정하고 통찰력 있는 꿈 해몽가이자 심리 상담가입니다.
                    다음은 사용자가 최근 기록한 3개의 꿈 내용입니다:
                    
                    {dreams}
                    
                    [작성 지침 - 반드시 엄수할 것]
                    1. 분량 제한: 전체 답변을 반드시 3~4문장(줄) 이내로 아주 짧게 작성하세요.
                    2. 디테일 언급 금지: 꿈에 등장한 구체적인 사물(예: 치킨, 피자 등)이나 사건을 있는 그대로 나열하거나 요약하지 마세요.
                    3. 패턴과 인사이트 도출: 3개의 꿈을 관통하는 공통된 감정, 분위기, 상징적 의미 등 '경향성'만 파악하세요.
                    4. 말투 및 구조: 친근하고 다정한 대화체(~해요, ~네요)를 사용하며, 아래의 흐름을 따라 자연스럽게 구성하세요.
                    - 도입: 최근 꿈들의 전반적인 흐름이나 감정 짚어주기 (예: "최근에는 어딘가로 훌쩍 떠나거나 쫓기는 꿈을 자주 꾸셨네요!")
                    - 의미: 그 흐름이 뜻하는 심리적/해몽적 의미 가볍게 설명 (예: "이런 꿈들은 보통 현실에서 휴식이 필요하거나 작은 변화를 원할 때 나타나곤 해요.")
                    - 마무리: 사용자의 현실 상황에 대한 따뜻한 공감, 질문 또는 격려 (예: "최근 부정적인 감정선이 자주 보이는데, 혹시 요즘 스트레스 받는 일이 있으셨나요? 오늘은 무거운 짐을 내려놓고 편안하게 잠드셨으면 좋겠어요.")"""
                )
        
        # LangChain v0.1.0 이상 권장 방식 (LCEL 파이프라인)
        chain = prompt | self.llm
        response = await chain.ainvoke({"dreams": dreams_text})
        
        return response.content