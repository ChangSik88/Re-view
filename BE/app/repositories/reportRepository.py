from datetime import datetime, timedelta, timezone
from app.core.db import db

# ZoneInfo("Asia/Seoul")은 Windows에 IANA tz DB가 없어 로컬 개발 시 실패한다.
KST = timezone(timedelta(hours=9))

class ReportRepository:
    # 1. 최근 N일간 작성된 일기 가져오기 (일기 본문이 작성된 방만, 시간순)
    async def get_recent_sessions(self, user_id: int, days: int):
        since = datetime.now(KST) - timedelta(days=days)
        return await db.chatroom.find_many(
            where={"user_id": user_id, "content": {"not": None}, "created_at": {"gte": since}},
            order={"created_at": "asc"}
        )

    # 2. 분석 결과 DB에 저장하기
    async def create_weekly_session(self, user_id: int, content: str, start_date, end_date):
        return await db.weeklysession.create(
            data={
                "user_id": user_id,
                "weekly_content": content,
                "start_date": start_date,
                "end_date": end_date
            }
        )

    async def get_latest_weekly_session(self, user_id: int):
        return await db.weeklysession.find_first(
            where={"user_id": user_id},
            order={"weekly_session_id": "desc"}  # 최신순 정렬 (스키마에 created_at이 있다고 가정, 없다면 end_date 사용)
        )
