"""Dream keyword extraction and JSON-backed interpretation lookup for the web demo."""

import json
import unicodedata
from functools import lru_cache
from pathlib import Path

from langchain_core.output_parsers import PydanticOutputParser
from langchain_core.prompts import ChatPromptTemplate
from pydantic import BaseModel, Field

from app.core.ai.langchainManager import llm


class DreamKeywordAnalysis(BaseModel):
    theme: str = Field(description="꿈의 핵심 주제를 짧게 표현")
    vibe: str = Field(description="꿈의 전반적인 분위기")
    suggested_feelings: list[str] = Field(description="꿈에서 느꼈을 법한 감정 단어 3개")
    ai_reply: str = Field(description="등록 키워드가 없을 때 사용할 일반 해몽")
    dream_category: str = Field(description="랭킹용 카테고리. 지정 목록에서 하나 선택")
    matched_keywords: list[str] = Field(
        description=(
            "꿈에 실제로 등장한 등록 표준 키워드 중 핵심 1~2개. "
            "목록과 정확히 같은 문자열만 반환하고, 없으면 빈 배열"
        )
    )


_DATA_FILE = Path(__file__).resolve().parents[2] / "data" / "dream_tarot.example.json"
_parser = PydanticOutputParser(pydantic_object=DreamKeywordAnalysis)


def _normalize_keyword(value: str) -> str:
    return unicodedata.normalize("NFC", value).strip()


@lru_cache(maxsize=1)
def _load_keyword_cards() -> dict[str, dict]:
    """Load and validate the small, version-controlled keyword catalog once."""
    data = json.loads(_DATA_FILE.read_text(encoding="utf-8"))
    cards = data.get("cards") if isinstance(data, dict) else None
    if not isinstance(cards, list):
        raise ValueError(f"키워드 카드 JSON에 cards 배열이 없습니다: {_DATA_FILE}")

    by_keyword: dict[str, dict] = {}
    required_fields = {
        "keyword",
        "category",
        "card_title",
        "advice",
        "positive_index",
        "negative_index",
        "positive_interpretation",
    }
    for card in cards:
        if not isinstance(card, dict) or not required_fields.issubset(card):
            raise ValueError("키워드 카드에 필수 필드가 빠져 있습니다.")

        keyword = _normalize_keyword(card["keyword"])
        if not keyword or keyword in by_keyword:
            raise ValueError(f"비어 있거나 중복된 표준 키워드입니다: {keyword!r}")
        if card["positive_index"] + card["negative_index"] != 100:
            raise ValueError(f"길흉 지수 합계가 100이 아닙니다: {keyword}")

        by_keyword[keyword] = card

    return by_keyword


async def analyze_dream_with_keyword_catalog(
    dream: str,
    ranking_categories: list[str],
) -> tuple[DreamKeywordAnalysis, list[dict]]:
    """Ask Gemini for standard keywords, then resolve them locally against JSON.

    The same Gemini response supplies a general-knowledge fallback. When a registered
    keyword is found, DemoService uses its stored card instead of that fallback.
    """
    cards_by_keyword = _load_keyword_cards()
    keyword_list = "\n".join(f"- {keyword}" for keyword in cards_by_keyword)
    category_list = ", ".join(ranking_categories)

    system_prompt = """당신은 꿈 내용을 분석하는 AI입니다.

아래 [등록 키워드]에서 꿈에 실제로 등장하거나 직접 표현된 핵심 키워드를 1~2개까지 선택하세요.
matched_keywords에는 목록에 있는 표준 키워드 문자열만 정확히 그대로 넣으세요.
꿈에 맞는 등록 키워드가 하나도 없으면 matched_keywords를 빈 배열로 반환하세요.
비슷해 보인다는 이유만으로 등록 키워드를 억지로 고르지 마세요.

ai_reply에는 등록 키워드가 없을 때 사용할 일반 해몽을 3~4문장으로 작성하세요. 꿈의 맥락을 고려하되
가능성으로 표현하고 길흉을 확정하지 마세요. 마지막에는 오늘을 위한 짧은 조언이나 질문을 덧붙이세요.
외부 자료를 검색했다고 주장하거나 출처를 만들지 마세요.
등록 키워드가 발견되면 백엔드가 JSON에 저장된 해석을 사용하므로 ai_reply는 결과에 사용되지 않습니다.

dream_category는 랭킹 전용입니다. 아래 [랭킹 카테고리] 중 하나만 선택하세요.
등록 키워드의 분야(category)와 랭킹 카테고리는 서로 다른 분류이므로 혼동하지 마세요.

[등록 키워드]
{keyword_list}

[랭킹 카테고리]
{category_list}

반드시 아래 JSON 스키마만 반환하세요.
{format_instructions}"""

    prompt = ChatPromptTemplate.from_messages(
        [
            ("system", system_prompt),
            ("user", "다음 꿈을 분석하세요.\n{dream}"),
        ]
    )
    chain = prompt | llm | _parser
    analysis = await chain.ainvoke(
        {
            "dream": dream,
            "keyword_list": keyword_list,
            "category_list": category_list,
            "format_instructions": _parser.get_format_instructions(),
        }
    )

    matches: list[dict] = []
    seen: set[str] = set()
    for candidate in analysis.matched_keywords:
        keyword = _normalize_keyword(candidate)
        card = cards_by_keyword.get(keyword)
        if card is not None and keyword not in seen:
            seen.add(keyword)
            matches.append(card)
        if len(matches) == 2:
            break

    # Discard model output that did not resolve to an exact catalog entry.
    analysis.matched_keywords = [card["keyword"] for card in matches]
    return analysis, matches
