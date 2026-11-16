from app.core.db import db
from app.repositories.consentRepository import ConsentRepository
from app.repositories.termsRepository import TermsRepository
from app.services.termsService import term_data


class ConsentConflict(ValueError):
    pass


class ConsentService:
    def __init__(self):
        self.repo = ConsentRepository()
        self.terms_repo = TermsRepository()

    async def validate(self, choices, client, signup=False):
        terms = await self.terms_repo.current(client)
        current = {term.term_id: term for term in terms if term.requires_consent}
        if signup and not any(term.is_required for term in current.values()):
            raise ConsentConflict("가입 약관이 등록되지 않았습니다.")
        ids = [choice["term_id"] for choice in choices]
        if len(ids) != len(set(ids)):
            raise ValueError("동일 약관을 중복 지정할 수 없습니다.")
        for choice in choices:
            term = current.get(choice["term_id"])
            if term is None:
                raise ConsentConflict("현재 동의 가능한 약관을 다시 조회해 주세요.")
            if term.is_required and not choice["is_agreed"]:
                raise ValueError("필수 약관에 동의해야 합니다.")
        if signup:
            accepted = {choice["term_id"] for choice in choices if choice["is_agreed"]}
            if any(term.is_required and term.term_id not in accepted for term in current.values()):
                raise ValueError("필수 약관 동의가 누락됐습니다.")
        return current

    async def status(self, user_id, client=None):
        client = client or db
        terms = await self.terms_repo.current(client)
        history = await self.repo.history(user_id, client)
        latest = {}
        for record in history:
            latest.setdefault(record.Term.term_type, record)
        result = []
        for term in terms:
            if not term.requires_consent:
                continue
            record = latest.get(term.term_type)
            same_version = record is not None and record.term_id == term.term_id
            result.append({
                **term_data(term),
                "is_agreed": bool(same_version and record.is_agreed and record.revoked_at is None),
                "decided_at": record.agreed_at if same_version else None,
                "revoked_at": record.revoked_at if same_version else None,
            })
        return result

    async def change(self, user_id, choices):
        async with db.tx() as tx:
            active = await tx.query_raw('SELECT user_id FROM users WHERE user_id = $1 FOR UPDATE', user_id)
            if not active or await tx.userwithdrawal.count(where={"user_id": user_id}):
                raise PermissionError("사용할 수 없는 계정입니다.")
            await self.validate(choices, tx)
            await self.repo.append(tx, user_id, choices)
            if not await self.repo.permits(tx, user_id, "research"):
                await tx.researchsample.delete_many(where={"user_id": user_id})
            return await self.status(user_id, tx)
