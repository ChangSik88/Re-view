from datetime import datetime
from app.core.db import db


class DemoRepository:
    # (오늘, 카테고리) 조합이 있으면 count+1, 없으면 새로 만든다.
    async def increment_category_count(self, target_date: datetime, category: str) -> None:
        await db.demodreamcount.upsert(
            where={"date_category": {"date": target_date, "category": category}},
            data={
                "create": {"date": target_date, "category": category, "count": 1},
                "update": {"count": {"increment": 1}},
            },
        )

    # "전체보기": 오늘 1건 이상 집계된 카테고리 전부, count 내림차순.
    # 동률은 카테고리 이름 가나다순(사용자 확정 규칙) — 상한(take)을 두지 않는다.
    async def get_today_ranking(self, target_date: datetime):
        return await db.demodreamcount.find_many(
            where={"date": target_date},
            order=[{"count": "desc"}, {"category": "asc"}],
        )
