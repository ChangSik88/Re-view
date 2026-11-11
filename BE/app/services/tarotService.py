from app.core.ai.dreamKeywordHarness import extract_tarot_keywords, find_cards, load_dream_tags, write_tarot_reading
from app.schemas.tarotSchema import TarotCard, TarotReading


class TarotService:
    # 꿈 문장 하나로 타로 카드 결과를 만든다. 로그인·저장 없이 웹 데모와 토스용 API가 함께 쓴다.
    async def create_reading(self, dream: str) -> TarotReading:
        extraction = await extract_tarot_keywords(dream)

        # 태그는 카드 제목이자 랭킹 집계 단위라 목록 밖 값을 대체할 "기타"가 없다.
        # 목록 밖이면 두 번째 호출 전에 실패시켜 호출하는 쪽이 오류로 처리하게 한다.
        tag = load_dream_tags().get(extraction.tag.strip())
        if tag is None:
            raise ValueError(f"태그 목록 밖의 값입니다: {extraction.tag!r}")

        cards = find_cards(extraction.matched_keywords)

        # 카드 아래 상세 설명은 최대 3개. 모델이 요소를 비워 보내면 찾은 카드 키워드로 대신한다.
        elements = extraction.dream_elements[:3] or [card["keyword"] for card in cards] or ["꿈"]
        writing = await write_tarot_reading(dream, elements, cards)

        # 등록 카드가 있으면 JSON의 제목을 쓰고, 없으면 Gemini가 지은 제목을 쓴다.
        # 사진은 태그 단위라 카드 제목과 상관없이 항상 있다(BE/scripts/build_tag_images.py가 만든다).
        image_url = f"/static/tagImages/normal/{tag['image_key']}.webp"
        if cards:
            card = TarotCard(keyword=cards[0]["keyword"], card_title=cards[0]["card_title"], image_url=image_url)
        else:
            card = TarotCard(keyword=elements[0], card_title=writing.card_title, image_url=image_url)

        return TarotReading(
            card=card,
            tag=tag["id"],
            summary=tag["definition"],
            details=writing.details[:3],
        )
