from app.core.db import db

class ReportRepository:
    # 1. 최근 3개 꿈 가져오기 (시간 역순)
    async def get_latest_sessions(self, user_id: int, limit: int = 3):
        return await db.chatsession.find_many(
            where={"user_id": user_id},
            order={"created_at": "desc"},
            take=limit
        )

    # 2. 분석 결과 DB에 저장하기
    async def create_weekly_session(self, user_id: int, content: str, start_date, end_date):
        return await db.weekly_session.create(
            data={
                "user_id": user_id,
                "weekly_content": content,
                "start_date": start_date,
                "end_date": end_date
            }
        )