from app.core.ai.dreamKeywordHarness import extract_tarot_keywords, find_cards, write_tarot_reading
from app.schemas.tarotSchema import TarotCard, TarotReading


class TarotService:
    # 꿈 문장 하나로 타로 카드 결과를 만든다. 로그인·저장 없이 웹 데모와 토스용 API가 함께 쓴다.
    async def create_reading(self, dream: str, ranking_categories: list[str]) -> TarotReading:
        extraction = await extract_tarot_keywords(dream, ranking_categories)
        cards = find_cards(extraction.matched_keywords)

        # 카드 아래 상세 설명은 최대 3개. 모델이 요소를 비워 보내면 찾은 카드 키워드로 대신한다.
        elements = extraction.dream_elements[:3] or [card["keyword"] for card in cards] or ["꿈"]
        writing = await write_tarot_reading(dream, elements, cards)

        # 등록 카드가 있으면 JSON의 제목을 쓰고, 없으면 Gemini가 지은 제목을 쓴다.
        if cards:
            card = TarotCard(keyword=cards[0]["keyword"], card_title=cards[0]["card_title"])
        else:
            card = TarotCard(keyword=elements[0], card_title=writing.card_title)

        return TarotReading(
            card=card,
            tags=writing.tags[:3],
            summary=writing.summary,
            details=writing.details[:3],
            dream_category=extraction.dream_category,
        )
