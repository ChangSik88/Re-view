from collections import Counter
from datetime import timedelta, timezone

from app.core.ai.reportManager import ReportManager
from app.repositories.reportRepository import ReportRepository

# ZoneInfo("Asia/Seoul")은 Windows에 IANA tz DB가 없어 로컬 개발 시 실패한다.
KST = timezone(timedelta(hours=9))
REPORT_PERIOD_DAYS = 7
TOP_TAG_COUNT = 5


class ReportService:
    def __init__(self):
        self.report_repo = ReportRepository()
        self.ai_manager = ReportManager()

    async def generate_and_save_report(self, user_id: int):
        # 1. 최근 7일간 작성된 일기 가져오기 (개수가 아니라 기간 기준 — 레코드가 몇 년에 걸쳐 섞이는 것을 방지)
        sessions = await self.report_repo.get_recent_sessions(user_id, REPORT_PERIOD_DAYS)

        if not sessions:
            raise ValueError(f"최근 {REPORT_PERIOD_DAYS}일간 작성된 일기가 없습니다.")

        # 2. 같은 날 아침/밤을 짝지어 요약하고, 태그를 집계해 통계 근거로 삼음
        daily_summary, tag_counts = self._summarize(sessions)
        top_tags = ", ".join(f"{tag}({count}회)" for tag, count in tag_counts.most_common(TOP_TAG_COUNT))

        # 3. AI 분석 실행 (원문 그대로가 아니라 위에서 만든 요약·통계를 근거로 넘김)
        analysis_result = await self.ai_manager.generate_insight(
            daily_summary=daily_summary,
            top_tags=top_tags or "집계된 태그가 없습니다."
        )

        # 4. 기간의 첫 날짜와 마지막 날짜 (sessions는 시간순 오름차순)
        start_date = sessions[0].created_at
        end_date = sessions[-1].created_at

        # 5. DB에 Weekly Session 생성
        saved_report = await self.report_repo.create_weekly_session(
            user_id=user_id,
            content=analysis_result,
            start_date=start_date,
            end_date=end_date
        )

        return saved_report

    def _summarize(self, sessions) -> tuple[str, Counter]:
        """같은 날(KST) 기록끼리 모닝/나이트로 묶어 날짜별 한 줄 요약을 만들고, 태그를 집계한다."""
        by_date: dict = {}
        tag_counts: Counter = Counter()
        for s in sessions:
            day = s.created_at.astimezone(KST).date()
            by_date.setdefault(day, {})[(s.routine_type or "").upper()] = s
            for tag in (s.tags or "").split(","):
                tag = tag.strip()
                if tag:
                    tag_counts[tag] += 1

        lines = []
        for day in sorted(by_date):
            morning = by_date[day].get("MORNING")
            night = by_date[day].get("NIGHT")
            parts = [f"{day.month}/{day.day}"]
            if morning:
                parts.append(f"아침 꿈 범주: {morning.dream_category or '미분류'} / 태그: {morning.tags or '없음'}")
            if night:
                parts.append(f"밤 하루 범주: {night.dream_category or '미분류'} / 태그: {night.tags or '없음'}")
            lines.append(" | ".join(parts))

        return "\n".join(lines), tag_counts

    async def get_user_report(self, user_id: int):
        report = await self.report_repo.get_latest_weekly_session(user_id)

        # 리포트가 아예 없을 수도 있으므로 None을 그대로 반환하여 프론트에서 처리하게 함
        return report
