import os
from datetime import date, datetime, time, timedelta, timezone
from typing import Dict, Tuple

from app.repositories.demoRepository import DemoRepository
from app.core.ai.langchainManager import analyze_dream_chat
from app.schemas.demoSchema import DemoInterpretResponse, DemoRankingResponse, DemoRankingItem

# 한국은 DST가 없어 고정 오프셋으로 충분하다.
# ZoneInfo("Asia/Seoul")은 Windows에 IANA tz DB가 없어 로컬 개발 시 실패한다.
KST = timezone(timedelta(hours=9))
IP_DAILY_LIMIT = 2
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
        self._ip_counts: Dict[str, Tuple[date, int]] = {}
        self._global_count: Tuple[date, int] = (_today_kst(), 0)
        self._global_limit = int(os.getenv("DEMO_DAILY_GLOBAL_LIMIT", "200"))

    def _get_ip_count(self, client_ip: str) -> int:
        today = _today_kst()
        last_date, count = self._ip_counts.get(client_ip, (today, 0))
        return count if last_date == today else 0

    def _get_global_count(self) -> int:
        today = _today_kst()
        last_date, count = self._global_count
        return count if last_date == today else 0

    def _increment_ip(self, client_ip: str) -> int:
        today = _today_kst()
        new_count = self._get_ip_count(client_ip) + 1
        self._ip_counts[client_ip] = (today, new_count)
        return new_count

    def _increment_global(self) -> None:
        today = _today_kst()
        self._global_count = (today, self._get_global_count() + 1)

    async def interpret(self, dream: str, client_ip: str) -> DemoInterpretResponse:
        if not (1 <= len(dream) <= 500):
            raise ValueError("꿈 내용은 1~500자로 입력해 주세요.")

        # 두 제한 모두 증가 없이 먼저 확인한다. 하나라도 거부되면 카운터를 건드리지 않는다.
        if self._get_ip_count(client_ip) >= IP_DAILY_LIMIT:
            raise DemoRateLimitError("ip")
        if self._get_global_count() >= self._global_limit:
            raise DemoRateLimitError("global")

        try:
            ai_result = await analyze_dream_chat(history="", new_message=dream, routine_type="MORNING")
        except Exception as e:
            print(f"데모 해몽 LLM 호출 실패: {e}")
            raise DemoUnavailableError()

        new_ip_count = self._increment_ip(client_ip)
        self._increment_global()

        category = ai_result.dream_category if ai_result.dream_category in CATEGORY_LIST else "기타"
        await self.demo_repo.increment_category_count(_today_kst_for_db(), category)

        return DemoInterpretResponse(
            theme=ai_result.theme,
            vibe=ai_result.vibe,
            suggested_feelings=ai_result.suggested_feelings,
            ai_reply=ai_result.ai_reply,
            remaining=IP_DAILY_LIMIT - new_ip_count,
            dream_category=category,  # 정규화된 값. "내가 해몽한 꿈" 표시는 FE가 이 값으로 전체보기 목록에서 매칭한다.
        )

    async def get_ranking(self) -> DemoRankingResponse:
        rows = await self.demo_repo.get_today_ranking(_today_kst_for_db())
        items = [DemoRankingItem(rank=i + 1, category=row.category) for i, row in enumerate(rows)]
        return DemoRankingResponse(date=_today_kst().isoformat(), items=items)
