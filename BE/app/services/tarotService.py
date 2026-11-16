from app.core.ai.dreamKeywordHarness import (
    extract_tarot_keywords,
    load_dream_tags,
    pick_main_case,
    resolve_case,
    write_tarot_reading,
)
from app.schemas.tarotSchema import TarotCard, TarotReading


class TarotService:
    # 꿈 문장 하나로 타로 카드 결과를 만든다. 로그인·저장 없이 웹 데모와 토스용 API가 함께 쓴다.
    async def create_reading(self, dream: str) -> TarotReading:
        extraction = await extract_tarot_keywords(dream)

        # 장면마다 노드를 찾고, 대표 카드는 card_rule대로 코드가 고른다.
        scenes = [(case.scene, resolve_case(case.object, case.action)) for case in extraction.cases]
        main = pick_main_case([found for _, found in scenes if found])

        if main is not None:
            tag = load_dream_tags()[main[0]["tag"]]
        else:
            # 장면이 하나도 목록에 안 맞을 때만 모델이 고른 태그를 쓴다.
            # 태그는 카드 제목이자 랭킹 집계 단위라 목록 밖 값을 대체할 "기타"가 없다.
            # 목록 밖이면 두 번째 호출 전에 실패시켜 호출하는 쪽이 오류로 처리하게 한다.
            tag = load_dream_tags().get(extraction.tag.strip())
            if tag is None:
                raise ValueError(f"태그 목록 밖의 값입니다: {extraction.tag!r}")

        # 카드 아래 상세 설명은 최대 3개. 대표 장면을 맨 앞에 두고 같은 노드는 한 번만 쓴다.
        ordered = sorted(scenes, key=lambda s: s[1] is not main) if main else scenes
        elements: list[tuple[str, dict | None]] = []
        seen: set[str] = set()
        for scene, found in ordered:
            node = found[0] if found else None
            key = node["keyword"] if node else scene
            if key not in seen:
                seen.add(key)
                elements.append((scene, node))
        elements = elements[:3] or [("꿈", None)]
        writing = await write_tarot_reading(dream, elements)

        # 대표 노드가 있으면 JSON의 제목을 쓰고, 없으면 Gemini가 지은 제목을 쓴다.
        # 사진은 태그 단위라 카드 제목과 상관없이 항상 있다(BE/scripts/build_tag_images.py가 만든다).
        image_url = f"/static/tagImages/normal/{tag['image_key']}.webp"
        if main is not None:
            card = TarotCard(keyword=main[0]["keyword"], card_title=main[0]["card_title"], image_url=image_url)
        else:
            card = TarotCard(keyword=elements[0][0], card_title=writing.card_title, image_url=image_url)

        return TarotReading(
            card=card,
            tag=tag["id"],
            summary=tag["definition"],
            details=writing.details[:3],
        )
