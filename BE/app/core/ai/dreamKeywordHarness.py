"""Dream keyword extraction and JSON-backed interpretation lookup for the web demo."""

import json
import unicodedata
from functools import lru_cache
from pathlib import Path

from langchain_core.output_parsers import PydanticOutputParser
from langchain_core.prompts import ChatPromptTemplate
from pydantic import BaseModel, Field

from app.core.ai.langchainManager import text_llm
from app.schemas.tarotSchema import TarotKeywordDetail


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
    tag: str = Field(description="[해몽 태그] 목록의 태그 이름 중 정확히 하나")


class TarotWriting(BaseModel):
    card_title: str = Field(description="등록 카드가 없을 때 쓸 카드 제목. 가장 중요한 꿈 요소의 의미를 담은 4~8자")
    details: list[TarotKeywordDetail] = Field(description="풀이할 꿈 요소 순서대로 요소마다 하나씩")


_DATA_FILE = Path(__file__).resolve().parents[2] / "data" / "dream_tarot.example.json"
_TAGS_FILE = Path(__file__).resolve().parents[2] / "data" / "dream_tags.json"
_tarot_extraction_parser = PydanticOutputParser(pydantic_object=TarotKeywordExtraction)
_tarot_writing_parser = PydanticOutputParser(pydantic_object=TarotWriting)


def _normalize_keyword(value: str) -> str:
    return unicodedata.normalize("NFC", value).strip()


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


@lru_cache(maxsize=1)
def load_dream_tags() -> dict[str, dict]:
    """해몽 태그 목록(dream_tags.json)을 한 번 읽어 태그 이름(id) → 태그 항목으로 돌려준다.
    카드에 보이는 태그와 랭킹 집계 단위가 모두 이 목록이다."""
    data = json.loads(_TAGS_FILE.read_text(encoding="utf-8"))
    tags = data.get("tags") if isinstance(data, dict) else None
    if not isinstance(tags, list):
        raise ValueError(f"태그 JSON에 tags 배열이 없습니다: {_TAGS_FILE}")

    by_id: dict[str, dict] = {}
    for tag in tags:
        tag_id = _normalize_keyword(tag.get("id", "")) if isinstance(tag, dict) else ""
        if not tag_id or tag_id in by_id or not tag.get("definition"):
            raise ValueError(f"비어 있거나 중복됐거나 정의가 없는 태그입니다: {tag_id!r}")
        by_id[tag_id] = tag

    return by_id


def find_cards(keywords: list[str]) -> list[dict]:
    """Return catalog cards for model-picked keywords, dropping anything not registered."""
    return _resolve_cards(keywords, _load_keyword_cards())


async def extract_tarot_keywords(dream: str) -> TarotKeywordExtraction:
    """Ask Gemini for the dream elements to explain, registered keywords and one dream tag."""
    system_prompt = """당신은 꿈 내용을 분석하는 AI입니다.

dream_elements에는 해몽할 꿈 속 핵심 요소를 1~3개 고르세요. 사물·인물·행동을 꿈에 나온 표현에 가깝게 쓰고(예: 뱀, 문을 여는 것),
아래 [등록 키워드]에 해당하는 요소부터 중요한 순서로 나열하세요.

matched_keywords에는 [등록 키워드]에서 꿈에 실제로 등장하거나 직접 표현된 핵심 키워드를 1~2개까지 고르세요.
목록에 있는 표준 키워드 문자열만 정확히 그대로 넣고, 맞는 키워드가 없으면 빈 배열로 반환하세요.
비슷해 보인다는 이유만으로 등록 키워드를 억지로 고르지 마세요.

tag에는 가장 중요한 꿈 요소가 꿈에서 하는 역할에 가장 잘 맞는 태그를 아래 [해몽 태그]에서 정확히 하나 고르세요.
목록의 각 줄은 "이름: 정의"입니다. tag 값에는 이름만 넣으세요(예: "전환"). 목록에 없는 말을 만들지 마세요.

[등록 키워드]
{keyword_list}

[해몽 태그]
{tag_list}

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
            "tag_list": "\n".join(f"- {tag_id}: {tag['definition']}" for tag_id, tag in load_dream_tags().items()),
            "format_instructions": _tarot_extraction_parser.get_format_instructions(),
        }
    )


async def write_tarot_reading(dream: str, elements: list[str], cards: list[dict]) -> TarotWriting:
    """Write the card title and per-element details shown under the tarot card."""
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
