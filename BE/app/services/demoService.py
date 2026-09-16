import os
from datetime import date, datetime, time, timedelta, timezone
from typing import Dict, Tuple

from app.repositories.demoRepository import DemoRepository
from app.core.ai.langchainManager import analyze_dream_chat
from app.schemas.demoSchema import DemoInterpretResponse, DemoRankingResponse, DemoRankingItem

# 한국은 DST가 없어 고정 오프셋으로 충분하다.
# ZoneInfo("Asia/Seoul")은 Windows에 IANA tz DB가 없어 로컬 개발 시 실패한다.
KST = timezone(timedelta(hours=9))
VISITOR_DAILY_LIMIT = 5
CATEGORY_LIST = [
    "쫓김", "이빨", "똥", "돼지", "조상님", "뱀", "불", "물", "높은곳", "피", "시험", "죽음", "기타",
]


class DemoRateLimitError(Exception):
    def __init__(self, reason: str):
        self.reason = reason


class DemoUnavailableError(Exception):
    pass


def _today_kst() -> date:
    """카운터 키·비교용 KST 날짜(메모리 안에서만 쓴다)."""
    return datetime.now(KST).date()


def _today_kst_for_db() -> datetime:
    """DB의 @db.Date 컬럼에 넘길 값. Prisma Python이 date를 직렬화하지 못해
    naive datetime(자정)으로 변환한다. tz-aware면 UTC 변환으로 날짜가 밀린다."""
    return datetime.combine(_today_kst(), time.min)


class DemoService:
    def __init__(self):
        self.demo_repo = DemoRepository()
        # 프로세스 메모리 카운터. Render 무료는 단일 인스턴스라 Redis 불필요.
        # 재배포·슬립 재시작 시 초기화되는 것은 허용된 한계(스펙 3.4).
        # 키는 IP가 아니라 방문자 ID(클라이언트가 localStorage에 만들어 헤더로 보내는
        # 값)다. IP는 공유 와이파이·CGNAT 뒤에서 여러 방문자가 같은 값을 갖게 되어
        # 정당한 사용자를 오탐 차단하는 문제가 있었다(ADR 0002).
        self._visitor_counts: Dict[str, Tuple[date, int]] = {}
        self._global_count: Tuple[date, int] = (_today_kst(), 0)
        self._global_limit = int(os.getenv("DEMO_DAILY_GLOBAL_LIMIT", "300"))

    def _get_visitor_count(self, visitor_id: str) -> int:
        today = _today_kst()
        last_date, count = self._visitor_counts.get(visitor_id, (today, 0))
        return count if last_date == today else 0

    def _get_global_count(self) -> int:
        today = _today_kst()
        last_date, count = self._global_count
        return count if last_date == today else 0

    def _increment_visitor(self, visitor_id: str) -> int:
        today = _today_kst()
        new_count = self._get_visitor_count(visitor_id) + 1
        self._visitor_counts[visitor_id] = (today, new_count)
        return new_count

    def _increment_global(self) -> None:
        today = _today_kst()
        self._global_count = (today, self._get_global_count() + 1)

    # 되돌리기는 증가 당시의 날짜(counted_date)를 받는다. 증가와 되돌리기 사이에는
    # LLM 호출(수 초)이 있어 그 사이 KST 자정을 넘길 수 있는데, 그러면 카운터는 이미
    # 새 날짜로 리셋됐고 거기 쌓인 값은 다른 요청의 것이다. 그때 빼면 남의 카운트를
    # 지우게 되므로, 날짜가 바뀌었으면 아무것도 하지 않는다(내 증가분은 이미 사라졌다).
    def _decrement_visitor(self, visitor_id: str, counted_date: date) -> None:
        stored_date, count = self._visitor_counts.get(visitor_id, (counted_date, 0))
        if stored_date != counted_date:
            return
        self._visitor_counts[visitor_id] = (stored_date, max(0, count - 1))

    def _decrement_global(self, counted_date: date) -> None:
        stored_date, count = self._global_count
        if stored_date != counted_date:
            return
        self._global_count = (stored_date, max(0, count - 1))

    async def interpret(self, dream: str, visitor_id: str) -> DemoInterpretResponse:
        dream = dream.strip()
        if not (1 <= len(dream) <= 500):
            raise ValueError("꿈 내용은 1~500자로 입력해 주세요.")

        # 확인과 증가 사이에 await를 두지 않는다. asyncio는 단일 스레드라 await가 없는
        # 구간은 원자적이다. 증가를 LLM 호출 뒤로 미루면 그 await에서 다른 요청들이
        # 전부 '증가 이전' 카운터를 보고 통과해 상한이 동시 요청 수만큼 새어나간다.
        if self._get_visitor_count(visitor_id) >= VISITOR_DAILY_LIMIT:
            raise DemoRateLimitError("visitor")
        if self._get_global_count() >= self._global_limit:
            raise DemoRateLimitError("global")

        counted_date = _today_kst()
        new_visitor_count = self._increment_visitor(visitor_id)
        self._increment_global()

        try:
            ai_result = await analyze_dream_chat(history="", new_message=dream, routine_type="MORNING")
        except Exception as e:
            # 실패한 시도가 사용자의 하루 한도를 깎지 않도록 되돌린다.
            self._decrement_visitor(visitor_id, counted_date)
            self._decrement_global(counted_date)
            print(f"데모 해몽 LLM 호출 실패: {e}")
            raise DemoUnavailableError()

        category = ai_result.dream_category if ai_result.dream_category in CATEGORY_LIST else "기타"
        try:
            await self.demo_repo.increment_category_count(_today_kst_for_db(), category)
        except Exception as e:
            # 랭킹 집계는 부가 기능이다. 여기서 실패해도 해몽 결과는 그대로 돌려준다.
            print(f"데모 랭킹 집계 실패: {e}")

        return DemoInterpretResponse(
            theme=ai_result.theme,
            vibe=ai_result.vibe,
            suggested_feelings=ai_result.suggested_feelings,
            ai_reply=ai_result.ai_reply,
            remaining=VISITOR_DAILY_LIMIT - new_visitor_count,
            dream_category=category,  # 정규화된 값. "내가 해몽한 꿈" 표시는 FE가 이 값으로 전체보기 목록에서 매칭한다.
        )

    async def get_ranking(self) -> DemoRankingResponse:
        rows = await self.demo_repo.get_today_ranking(_today_kst_for_db())
        items = [DemoRankingItem(rank=i + 1, category=row.category) for i, row in enumerate(rows)]
        return DemoRankingResponse(date=_today_kst().isoformat(), items=items)
