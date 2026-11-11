import os
from datetime import date, datetime, time, timedelta, timezone
from typing import Dict, Tuple

from app.repositories.demoRepository import DemoRepository
from app.core.ai.dreamKeywordHarness import load_dream_tags
from app.services.tarotService import TarotService
from app.schemas.demoSchema import DemoRankingResponse, DemoRankingItem, DemoTarotResponse

# 한국은 DST가 없어 고정 오프셋으로 충분하다.
# ZoneInfo("Asia/Seoul")은 Windows에 IANA tz DB가 없어 로컬 개발 시 실패한다.
KST = timezone(timedelta(hours=9))
VISITOR_DAILY_LIMIT = 5


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
        self.tarot_service = TarotService()
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

    @staticmethod
    def _clean_dream(dream: str) -> str:
        dream = dream.strip()
        if not (1 <= len(dream) <= 500):
            raise ValueError("꿈 내용은 1~500자로 입력해 주세요.")
        return dream

    def _reserve(self, visitor_id: str) -> Tuple[date, int]:
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
        return counted_date, new_visitor_count

    def _release(self, visitor_id: str, counted_date: date) -> None:
        # 실패한 시도가 사용자의 하루 한도를 깎지 않도록 되돌린다.
        self._decrement_visitor(visitor_id, counted_date)
        self._decrement_global(counted_date)

    async def _count_tag(self, tag: str) -> None:
        try:
            await self.demo_repo.increment_category_count(_today_kst_for_db(), tag)
        except Exception as e:
            # 랭킹 집계는 부가 기능이다. 여기서 실패해도 해몽 결과는 그대로 돌려준다.
            print(f"데모 랭킹 집계 실패: {e}")

    async def tarot(self, dream: str, visitor_id: str) -> DemoTarotResponse:
        dream = self._clean_dream(dream)
        counted_date, new_visitor_count = self._reserve(visitor_id)

        try:
            reading = await self.tarot_service.create_reading(dream)
        except Exception as e:
            self._release(visitor_id, counted_date)
            print(f"데모 타로 해몽 처리 실패: {e}")
            raise DemoUnavailableError()

        await self._count_tag(reading.tag)
        return DemoTarotResponse(
            **reading.model_dump(),
            remaining=VISITOR_DAILY_LIMIT - new_visitor_count,
        )

    async def get_ranking(self) -> DemoRankingResponse:
        # 현재 태그 목록에 있는 행만 센다. 태그 전환 전의 옛 카테고리 행(뱀, 이빨 등)과
        # 나중에 목록에서 빠진 태그는 DB에 남아도 랭킹에 나오지 않는다.
        tags = load_dream_tags()
        rows = await self.demo_repo.get_today_ranking(_today_kst_for_db(), list(tags))
        items = [
            DemoRankingItem(rank=i + 1, tag=row.category, definition=tags[row.category]["definition"])
            for i, row in enumerate(rows)
        ]
        return DemoRankingResponse(date=_today_kst().isoformat(), items=items)
