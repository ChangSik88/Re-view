from datetime import datetime, timezone

from app.core.db import db


class ConsentRepository:
    async def history(self, user_id, client=None):
        return await (client or db).userconsent.find_many(
            where={"user_id": user_id},
            include={"Term": True},
            order={"consent_id": "desc"},
        )

    async def append(self, client, user_id, choices):
        now = datetime.now(timezone.utc)
        for choice in choices:
            await client.userconsent.create(data={
                "user_id": user_id,
                "term_id": choice["term_id"],
                "is_agreed": choice["is_agreed"],
                "agreed_at": now,
                "revoked_at": None if choice["is_agreed"] else now,
            })

    async def revoke_optional(self, client, user_id):
        history = await self.history(user_id, client)
        latest = {}
        for record in history:
            latest.setdefault(record.Term.term_type, record)
        choices = [
            {"term_id": row.term_id, "is_agreed": False}
            for row in latest.values()
            if row.is_agreed and not row.Term.is_required
        ]
        await self.append(client, user_id, choices)
        await client.researchsample.delete_many(where={"user_id": user_id})

    async def permits(self, client, user_id, term_type):
        active = await client.user.find_first(where={
            "user_id": user_id, "UserWithdrawal": {"none": {}},
        })
        if not active:
            return False
        # 과거 버전에 대한 동의가 새 버전의 활용 근거가 되지 않도록 한다.
        from app.repositories.termsRepository import TermsRepository
        current = await TermsRepository().current(client)
        term = next((row for row in current if row.term_type == term_type and row.requires_consent), None)
        if term is None:
            return False
        record = await client.userconsent.find_first(
            where={"user_id": user_id, "Term": {"is": {"term_type": term_type}}},
            order={"consent_id": "desc"},
        )
        return bool(record and record.term_id == term.term_id and record.is_agreed and record.revoked_at is None)
