from datetime import datetime, timezone

from app.core.db import db


class TermsRepository:
    async def current(self, client=None):
        client = client or db
        rows = await client.term.find_many(
            where={"is_active": True, "effective_at": {"lte": datetime.now(timezone.utc)}},
            order=[{"effective_at": "desc"}, {"term_id": "desc"}],
        )
        latest = {}
        for term in rows:
            latest.setdefault(term.term_type, term)
        return list(latest.values())

    async def get(self, term_id, client=None):
        return await (client or db).term.find_unique(where={"term_id": term_id})
