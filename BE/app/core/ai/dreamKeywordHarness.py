"""꿈을 장면으로 나눠 노드(dream_nodes.json)에 맞추고, card_rule로 대표 카드를 고르는 웹 데모용 하네스."""

import json
import unicodedata
from collections import Counter
from functools import lru_cache
from pathlib import Path

from langchain_core.output_parsers import PydanticOutputParser
from langchain_core.prompts import ChatPromptTemplate
from pydantic import BaseModel, Field

from app.core.ai.langchainManager import tag_llm, text_llm
from app.schemas.tarotSchema import TarotKeywordDetail


class DreamCase(BaseModel):
    scene: str = Field(description="이 장면을 가리키는 꿈 속 표현. 꿈에 나온 말에 가깝게 짧게")
    object: str | None = Field(default=None, description="[대상] 목록의 문자열 하나. 없으면 null")
    action: str | None = Field(default=None, description="[행동] 목록의 문자열 하나. 없으면 null")


class TarotKeywordExtraction(BaseModel):
    cases: list[DreamCase] = Field(description="꿈 속 장면 1~5개. 꿈에 나온 순서대로")
    tag: str = Field(description="[해몽 태그] 목록의 태그 이름 중 정확히 하나. 장면이 목록과 하나도 안 맞을 때만 쓴다")


class TarotWriting(BaseModel):
    card_title: str = Field(description="등록 해석이 하나도 없을 때 쓸 카드 제목. 첫 번째 꿈 요소의 의미를 담은 4~8자")
    details: list[TarotKeywordDetail] = Field(description="풀이할 꿈 요소 순서대로 요소마다 하나씩")


_DATA_DIR = Path(__file__).resolve().parents[2] / "data"
_TAGS_FILE = _DATA_DIR / "dream_tags.json"
_NODES_FILE = _DATA_DIR / "dream_nodes.json"
_COMBOS_FILE = _DATA_DIR / "dream_combos.json"
_tarot_extraction_parser = PydanticOutputParser(pydantic_object=TarotKeywordExtraction)
_tarot_writing_parser = PydanticOutputParser(pydantic_object=TarotWriting)


def _normalize_keyword(value: str) -> str:
    return unicodedata.normalize("NFC", value).strip()


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
        if not tag_id or tag_id in by_id or not all(tag.get(k) for k in ("definition", "explanation", "image_key")):
            raise ValueError(f"비어 있거나 중복됐거나 정의, 풀이, 사진 키가 없는 태그입니다: {tag_id!r}")
        by_id[tag_id] = tag

    return by_id


@lru_cache(maxsize=1)
def load_dream_nodes() -> tuple[dict[str, dict], dict[tuple[str, str], dict]]:
    """노드(dream_nodes.json)와 조합표(dream_combos.json)를 한 번 읽는다.
    돌려주는 값은 (키워드와 별칭 → 노드, (대상 키워드, 행동 키워드) → 조합 결과 노드)다."""
    tags = load_dream_tags()
    by_name: dict[str, dict] = {}
    for node in json.loads(_NODES_FILE.read_text(encoding="utf-8"))["nodes"]:
        if node.get("type") not in ("object", "action") or node.get("tag") not in tags or not node.get("card_title"):
            raise ValueError(f"type, tag, card_title이 잘못된 노드입니다: {node.get('keyword')!r}")
        for name in [node["keyword"], *node["aliases"]]:
            name = _normalize_keyword(name)
            if not name or name in by_name:
                raise ValueError(f"비어 있거나 중복된 키워드, 별칭입니다: {name!r}")
            by_name[name] = node

    combos: dict[tuple[str, str], dict] = {}
    for combo in json.loads(_COMBOS_FILE.read_text(encoding="utf-8"))["combos"]:
        obj, act, result = (by_name.get(combo[k]) for k in ("object", "action", "node"))
        if not (obj and act and result) or obj["type"] != "object" or act["type"] != "action":
            raise ValueError(f"조합표 항목이 노드와 맞지 않습니다: {combo}")
        combos[(obj["keyword"], act["keyword"])] = result
    return by_name, combos


def resolve_case(obj: str | None, act: str | None) -> tuple[dict, bool] | None:
    """케이스 하나를 노드로 바꾼다. 돌려주는 값은 (노드, 행동에서 나왔는지)이고 목록 밖이면 None이다.
    조합표, 행동, 대상 순으로 보고, 범용 동사(generic)는 대상이 있으면 대상에 양보한다."""
    by_name, combos = load_dream_nodes()
    # 모델이 목록의 "키워드 (별칭)" 줄을 통째로 베끼는 경우가 있어 괄호 앞까지만 본다.
    found = [by_name.get(_normalize_keyword(name.split("(")[0])) for name in (obj, act) if name]
    # 모델이 칸을 바꿔 넣어도 노드의 type으로 다시 나눈다.
    o = next((n for n in found if n and n["type"] == "object"), None)
    a = next((n for n in found if n and n["type"] == "action"), None)
    if o and a and (o["keyword"], a["keyword"]) in combos:
        return combos[(o["keyword"], a["keyword"])], True
    if a and not (a.get("generic") and o):
        return a, not a.get("generic")
    node = o or a
    return (node, False) if node else None


def pick_main_case(resolved: list[tuple[dict, bool]]) -> tuple[dict, bool] | None:
    """dream_tags.json의 card_rule대로 대표 케이스를 고른다. resolved는 꿈에 나온 순서다."""
    if not resolved:
        return None
    tags = load_dream_tags()

    def tier(case: tuple[dict, bool]) -> int:
        node, from_action = case
        t = tags[node["tag"]]["tier"]
        return 2 if t == 1 and not from_action else t

    top = min(tier(c) for c in resolved)
    cand = [c for c in resolved if tier(c) == top]
    counts = Counter(node["tag"] for node, _ in cand)
    best = max(counts.values())
    tied = [t for t in counts if counts[t] == best]
    if len(tied) > 1:
        tied = [t for t in tied if any(fa and node["tag"] == t for node, fa in cand)] or tied
    return next(c for c in cand if c[0]["tag"] in tied)


@lru_cache(maxsize=2)
def _node_list(node_type: str) -> str:
    nodes = {n["keyword"]: n for n in load_dream_nodes()[0].values() if n["type"] == node_type}.values()
    return "\n".join(
        f"- {n['keyword']}" + (f" ({', '.join(n['aliases'])})" if n["aliases"] else "") for n in nodes
    )


async def extract_tarot_keywords(dream: str) -> TarotKeywordExtraction:
    """Gemini(온도 0)가 꿈을 장면으로 나누고 장면마다 대상, 행동을 목록에서 고른다. 판단은 코드가 한다."""
    system_prompt = """당신은 꿈 내용을 장면으로 나누는 AI입니다. 판단하지 말고 목록에서 고르기만 하세요.

cases에는 꿈의 중요한 장면을 1~5개, 꿈에 나온 순서대로 넣으세요.
- scene: 그 장면을 가리키는 꿈 속 표현을 짧게 쓰세요(예: 이가 부서짐, 호수로 미끄러진 차).
- object: 장면의 중심 대상을 [대상] 목록에서 정확히 같은 문자열로 하나 고르세요. 괄호 안 별칭도 그대로 쓸 수 있습니다. 없으면 null.
- action: 장면에서 일어난 일을 [행동] 목록에서 정확히 같은 문자열로 하나 고르세요. 없으면 null.
- 꿈꾼 사람이 한 일뿐 아니라 다른 인물이나 사물에게 일어난 일도 장면으로 넣으세요.
- 배경으로 스쳐 지나간 것은 넣지 마세요.
- 장난이나 놀이처럼 위협이 아닌 일에는 공격당하다, 사고 같은 무거운 행동을 고르지 마세요.
  예: 동물이 장난으로 손을 깨문 장면은 공격당하다가 아니라 놀다를 고르거나 action을 null로 두세요.
- 비슷해 보인다는 이유만으로 억지로 고르지 마세요. 목록에 맞는 것이 없으면 null로 두세요.

tag에는 꿈 전체에 가장 잘 맞는 태그를 [해몽 태그]에서 정확히 하나 고르세요. 장면이 목록과 하나도 안 맞을 때만 쓰입니다.
목록의 각 줄은 "이름: 정의"입니다. tag 값에는 이름만 넣으세요(예: "전환").

[대상]
{object_list}

[행동]
{action_list}

[해몽 태그]
{tag_list}

반드시 아래 JSON 스키마만 반환하세요.
{format_instructions}"""
    prompt = ChatPromptTemplate.from_messages(
        [("system", system_prompt), ("user", "다음 꿈을 분석하세요.\n{dream}")]
    )
    chain = prompt | tag_llm | _tarot_extraction_parser
    return await chain.ainvoke(
        {
            "dream": dream,
            "object_list": _node_list("object"),
            "action_list": _node_list("action"),
            "tag_list": "\n".join(f"- {tag_id}: {tag['definition']}" for tag_id, tag in load_dream_tags().items()),
            "format_instructions": _tarot_extraction_parser.get_format_instructions(),
        }
    )


async def write_tarot_reading(dream: str, elements: list[tuple[str, dict | None]]) -> TarotWriting:
    """카드 아래 요소별 설명과, 등록 해석이 없을 때 쓸 카드 제목을 쓴다. elements는 (꿈 속 표현, 노드 또는 None)이다."""
    element_context = json.dumps(
        [
            {"element": scene}
            | (
                {
                    "interpretation": node["modern_interpretation"],
                    "advice": node["advice"],
                }
                if node
                else {}
            )
            for scene, node in elements
        ],
        ensure_ascii=False,
        indent=2,
    )
    system_prompt = """당신은 꿈을 타로 카드 형식으로 풀이합니다. 아래 [꿈], [풀이할 꿈 요소]를 읽고 카드 아래에 들어갈 글을 쓰세요.

[작성 규칙]
- card_title: 첫 번째 꿈 요소의 의미를 담은 4~8자 카드 제목을 지으세요. 예: 변화의 문, 잠든 힘의 각성
- details: [풀이할 꿈 요소] 순서대로 요소마다 하나씩 쓰세요. keyword에는 element를 그대로 쓰고,
  description은 keyword로 문장을 시작해 2~3문장의 ~해요체로 쓰세요.
- interpretation과 advice가 있는 요소는 그 내용을 근거로 쓰세요. 없는 요소는 지금 마음 상태에 대한 가능성으로 쓰세요.
- 두 번째 요소부터는 앞의 요소와 함께 나온 의미를 이어서 풀이하세요.
- 좋은 꿈, 나쁜 꿈 같은 길흉 판단과 "~할 것이다" 같은 예언은 쓰지 마세요. 외부 검색이나 출처를 지어내지 마세요.

[꿈]
{dream}

[풀이할 꿈 요소]
{element_context}

반드시 아래 JSON 스키마만 반환하세요.
{format_instructions}"""
    prompt = ChatPromptTemplate.from_messages(
        [("system", system_prompt), ("user", "타로 카드 아래에 들어갈 풀이를 작성하세요.")]
    )
    chain = prompt | text_llm | _tarot_writing_parser
    return await chain.ainvoke(
        {
            "dream": dream,
            "element_context": element_context,
            "format_instructions": _tarot_writing_parser.get_format_instructions(),
        }
    )
