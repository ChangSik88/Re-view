from pydantic import BaseModel
from typing import List


class DemoInterpretRequest(BaseModel):
    dream: str


class DemoInterpretResponse(BaseModel):
    theme: str
    vibe: str
    suggested_feelings: List[str]
    ai_reply: str
    remaining: int
    dream_category: str  # "내가 해몽한 꿈" 표시용. 정규화된 값(목록 밖이면 "기타")을 그대로 노출한다.


class DemoRankingItem(BaseModel):
    rank: int
    category: str


class DemoRankingResponse(BaseModel):
    date: str
    items: List[DemoRankingItem]  # 상한 없음. 그날 1건 이상 집계된 카테고리만 전부 담긴다.
