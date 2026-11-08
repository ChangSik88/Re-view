"""Dream keyword extraction and JSON-backed interpretation lookup for the web demo."""

import json
import unicodedata
from functools import lru_cache
from pathlib import Path

from langchain_core.output_parsers import PydanticOutputParser
from langchain_core.prompts import ChatPromptTemplate
from pydantic import BaseModel, Field

from app.core.ai.langchainManager import llm, text_llm
from app.schemas.tarotSchema import TarotKeywordDetail


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


class CatalogDreamSynthesis(BaseModel):
    theme: str = Field(description="꿈의 전체 맥락과 등록 키워드 해석을 합친 짧은 제목")
    ai_reply: str = Field(description="등록 키워드 해석들을 하나로 통합한 해몽과 조언")


class TarotKeywordExtraction(BaseModel):
    dream_elements: list[str] = Field(
        description=(
            "풀이할 꿈 속 핵심 요소 1~3개. 사물·인물·행동을 꿈에 나온 표현에 가깝게, "
            "등록 키워드에 해당하는 요소부터 중요한 순서로"
        )
    )
    matched_keywords: list[str] = Field(
        description=(
            "꿈에 실제로 등장한 등록 표준 키워드 중 핵심 1~2개. "
            "목록과 정확히 같은 문자열만 반환하고, 없으면 빈 배열"
        )
    )
    dream_category: str = Field(description="랭킹용 카테고리. 지정 목록에서 하나 선택")


class TarotWriting(BaseModel):
    card_title: str = Field(description="등록 카드가 없을 때 쓸 카드 제목. 가장 중요한 꿈 요소의 의미를 담은 4~8자")
    tags: list[str] = Field(description="카드에 붙일 짧은 태그 2~3개. '#' 없이 단어만")
    summary: str = Field(description="'[가장 중요한 꿈 요소] 꿈은 ~예요' 형태의 한 줄 설명")
    details: list[TarotKeywordDetail] = Field(description="풀이할 꿈 요소 순서대로 요소마다 하나씩")


_DATA_FILE = Path(__file__).resolve().parents[2] / "data" / "dream_tarot.example.json"
_parser = PydanticOutputParser(pydantic_object=DreamKeywordAnalysis)
_synthesis_parser = PydanticOutputParser(pydantic_object=CatalogDreamSynthesis)
_tarot_extraction_parser = PydanticOutputParser(pydantic_object=TarotKeywordExtraction)
_tarot_writing_parser = PydanticOutputParser(pydantic_object=TarotWriting)


def _normalize_keyword(value: str) -> str:
    return unicodedata.normalize("NFC", value).strip()


def format_card_context(cards: list[dict]) -> str:
    return json.dumps(
        [
            {
                "keyword": card["keyword"],
                "interpretation": card["positive_interpretation"],
                "advice": card["advice"],
            }
            for card in cards
        ],
        ensure_ascii=False,
        indent=2,
    )


def _resolve_cards(candidates: list[str], cards_by_keyword: dict[str, dict]) -> list[dict]:
    """Keep up to two distinct model outputs that exactly match a catalog entry."""
    matches: list[dict] = []
    seen: set[str] = set()
    for candidate in candidates:
        keyword = _normalize_keyword(candidate)
        card = cards_by_keyword.get(keyword)
        if card is not None and keyword not in seen:
            seen.add(keyword)
            matches.append(card)
        if len(matches) == 2:
            break
    return matches


async def _synthesize_catalog_interpretation(
    dream: str,
    matched_cards: list[dict],
) -> CatalogDreamSynthesis:
    """Combine matched card meanings into one reading grounded in the dream context."""
    card_context = format_card_context(matched_cards)
    system_prompt = """당신은 등록된 꿈 키워드 카드의 내용을 근거로 꿈 전체를 해석합니다.

아래 [꿈]의 장면과 [등록 카드 해석]을 함께 읽고 하나의 자연스러운 해몽을 작성하세요.
키워드별 뜻을 따로 나열하거나 카드 문장을 단순히 이어 붙이지 마세요. 꿈에서 각 대상이 어떤 행동과 관계를 맺는지 보고, 카드 해석들을 하나의 공통된 의미로 엮으세요.

등록 카드의 해석과 조언만 근거로 삼으세요. 카드에 없는 상징 풀이를 새로 만들거나 길흉을 확정하지 말고 가능성으로 표현하세요. ai_reply는 통합된 해몽 2~3문장과 카드 조언들을 반영한 실천 가능한 제안 한 문장으로 작성하세요. theme은 통합된 의미를 나타내는 짧은 한국어 제목으로 작성하세요.
외부 검색을 했다고 주장하거나 출처를 만들지 마세요.

[꿈]
{dream}

[등록 카드 해석]
{card_context}

반드시 아래 JSON 스키마만 반환하세요.
{format_instructions}"""
    prompt = ChatPromptTemplate.from_messages(
        [("system", system_prompt), ("user", "등록 카드 내용을 꿈의 맥락에 맞춰 통합하세요.")]
    )
    chain = prompt | llm | _synthesis_parser
    return await chain.ainvoke(
        {
            "dream": dream,
            "card_context": card_context,
            "format_instructions": _synthesis_parser.get_format_instructions(),
        }
    )


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
) -> DreamKeywordAnalysis:
    """Ask Gemini for standard keywords, then resolve them locally against JSON.

    The first Gemini response supplies a general-knowledge fallback. When registered
    keywords are found, a second Gemini call combines their stored card meanings into
    one reading grounded in the original dream.
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
등록 키워드가 발견되면 백엔드가 JSON에 저장된 해석과 조언을 바탕으로 별도의 통합 해몽을 생성하므로
이 단계의 ai_reply는 결과에 사용되지 않습니다.

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

    matches = _resolve_cards(analysis.matched_keywords, cards_by_keyword)

    # Discard model output that did not resolve to an exact catalog entry.
    analysis.matched_keywords = [card["keyword"] for card in matches]
    if matches:
        synthesis = await _synthesize_catalog_interpretation(dream, matches)
        analysis.theme = synthesis.theme
        analysis.ai_reply = synthesis.ai_reply

    return analysis


def find_cards(keywords: list[str]) -> list[dict]:
    """Return catalog cards for model-picked keywords, dropping anything not registered."""
    return _resolve_cards(keywords, _load_keyword_cards())


async def extract_tarot_keywords(dream: str, ranking_categories: list[str]) -> TarotKeywordExtraction:
    """Ask Gemini for the dream elements to explain, registered keywords and ranking category."""
    system_prompt = """당신은 꿈 내용을 분석하는 AI입니다.

dream_elements에는 해몽할 꿈 속 핵심 요소를 1~3개 고르세요. 사물·인물·행동을 꿈에 나온 표현에 가깝게 쓰고(예: 뱀, 문을 여는 것),
아래 [등록 키워드]에 해당하는 요소부터 중요한 순서로 나열하세요.

matched_keywords에는 [등록 키워드]에서 꿈에 실제로 등장하거나 직접 표현된 핵심 키워드를 1~2개까지 고르세요.
목록에 있는 표준 키워드 문자열만 정확히 그대로 넣고, 맞는 키워드가 없으면 빈 배열로 반환하세요.
비슷해 보인다는 이유만으로 등록 키워드를 억지로 고르지 마세요.

dream_category는 랭킹 전용입니다. 아래 [랭킹 카테고리] 중 하나만 선택하세요.
등록 키워드의 분야(category)와 랭킹 카테고리는 서로 다른 분류이므로 혼동하지 마세요.

[등록 키워드]
{keyword_list}

[랭킹 카테고리]
{category_list}

반드시 아래 JSON 스키마만 반환하세요.
{format_instructions}"""
    prompt = ChatPromptTemplate.from_messages(
        [("system", system_prompt), ("user", "다음 꿈을 분석하세요.\n{dream}")]
    )
    chain = prompt | text_llm | _tarot_extraction_parser
    return await chain.ainvoke(
        {
            "dream": dream,
            "keyword_list": "\n".join(f"- {keyword}" for keyword in _load_keyword_cards()),
            "category_list": ", ".join(ranking_categories),
            "format_instructions": _tarot_extraction_parser.get_format_instructions(),
        }
    )


async def write_tarot_reading(dream: str, elements: list[str], cards: list[dict]) -> TarotWriting:
    """Write the tag, one-line summary and per-element details shown under the tarot card."""
    card_context = json.dumps(
        [
            {
                "keyword": card["keyword"],
                "card_title": card["card_title"],
                "interpretation": card["positive_interpretation"],
                "advice": card["advice"],
                "positive_index": card["positive_index"],
                "negative_index": card["negative_index"],
            }
            for card in cards
        ],
        ensure_ascii=False,
        indent=2,
    ) if cards else "없음"
    system_prompt = """당신은 꿈을 타로 카드 형식으로 풀이합니다. 아래 [꿈], [풀이할 꿈 요소], [등록 카드]를 읽고 카드 아래에 들어갈 글을 쓰세요.

[작성 규칙]
- card_title: [등록 카드]가 있으면 첫 카드의 card_title을 그대로 쓰세요. "없음"이면 첫 번째 꿈 요소의 의미를 담은
  4~8자 카드 제목을 지으세요. 예: 변화의 문, 잠든 힘의 각성
- tags: 꿈의 분위기와 의미를 담은 짧은 태그 2~3개. '#' 없이 단어만 쓰세요.
- summary: "[가장 중요한 꿈 요소] 꿈은 ~예요" 형태의 한 문장으로, 40자 이내로 쓰세요.
- details: [풀이할 꿈 요소] 순서대로 요소마다 하나씩 쓰세요. keyword에는 요소를 그대로 쓰고,
  description은 keyword로 문장을 시작해 2~3문장의 ~해요체로 쓰세요.
- [등록 카드]와 같은 요소는 카드의 해석과 조언을 근거로 쓰고, 길흉 지수(positive_index, negative_index)를
  "길흉이 반반이라", "좋은 쪽이 우세해서"처럼 쉬운 말로 함께 알려 주세요.
- [등록 카드]에 없는 요소는 전통 해몽을 바탕으로 가능성으로 표현하세요.
- 두 번째 요소부터는 앞의 요소와 함께 나온 의미를 이어서 풀이하세요.
- 카드에 없는 내용을 카드 해석인 것처럼 쓰거나 길흉을 확정하지 마세요. 외부 검색이나 출처를 지어내지 마세요.

[꿈]
{dream}

[풀이할 꿈 요소]
{elements}

[등록 카드]
{card_context}

반드시 아래 JSON 스키마만 반환하세요.
{format_instructions}"""
    prompt = ChatPromptTemplate.from_messages(
        [("system", system_prompt), ("user", "타로 카드 아래에 들어갈 풀이를 작성하세요.")]
    )
    chain = prompt | text_llm | _tarot_writing_parser
    return await chain.ainvoke(
        {
            "dream": dream,
            "elements": "\n".join(f"- {element}" for element in elements),
            "card_context": card_context,
            "format_instructions": _tarot_writing_parser.get_format_instructions(),
        }
    )
