from pydantic import BaseModel
from typing import List

from app.schemas.tarotSchema import TarotReading


class DemoInterpretRequest(BaseModel):
    dream: str


class DemoTarotResponse(TarotReading):
    remaining: int


class DemoRankingItem(BaseModel):
    rank: int
    tag: str  # "나의 태그" 표시는 FE가 /demo/tarot의 tag와 이 값을 맞춰 본다.
    definition: str
    explanation: str  # 펼침 패널의 태그 풀이. dream_tags.json 원문 그대로다.


class DemoRankingResponse(BaseModel):
    date: str
    items: List[DemoRankingItem]  # 상한 없음. 그날 1건 이상 집계된 태그만 전부 담긴다.
