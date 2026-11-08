from typing import List

from pydantic import BaseModel, Field


class TarotCard(BaseModel):
    # 등록 키워드가 있으면 JSON 카탈로그의 표준 키워드와 카드 제목,
    # 없으면 가장 중요한 꿈 요소와 Gemini가 지은 카드 제목(카탈로그에 없어 카드 그림도 없다).
    keyword: str
    card_title: str


class TarotKeywordDetail(BaseModel):
    keyword: str = Field(description="설명할 꿈 요소. 꿈에 나온 표현에 가깝게")
    description: str = Field(description="keyword로 시작하는 2~3문장의 ~해요체 설명")


class TarotReading(BaseModel):
    card: TarotCard
    tags: List[str]
    summary: str
    details: List[TarotKeywordDetail]
    dream_category: str  # 랭킹용. 목록 밖 값의 정규화는 호출하는 쪽이 한다.
