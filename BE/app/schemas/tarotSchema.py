from typing import List

from pydantic import BaseModel, Field


class TarotCard(BaseModel):
    # 등록 키워드가 있으면 JSON 카탈로그의 표준 키워드와 카드 제목,
    # 없으면 가장 중요한 꿈 요소와 Gemini가 지은 카드 제목.
    keyword: str
    card_title: str
    # 태그 카드 사진의 상대 경로(/static/...). 웹과 토스는 API 주소를 앞에 붙여 쓴다.
    image_url: str


class TarotKeywordDetail(BaseModel):
    keyword: str = Field(description="설명할 꿈 요소. 꿈에 나온 표현에 가깝게")
    description: str = Field(description="keyword로 시작하는 2~3문장의 ~해요체 설명")


class TarotReading(BaseModel):
    card: TarotCard
    tag: str  # dream_tags.json의 태그 이름. 웹 랭킹도 같은 값으로 집계한다.
    summary: str  # 태그의 한 줄 정의
    details: List[TarotKeywordDetail]
