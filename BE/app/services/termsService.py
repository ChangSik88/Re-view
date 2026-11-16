from app.repositories.termsRepository import TermsRepository


def term_data(term, detail=False):
    data = {
        "term_id": term.term_id,
        "term_type": term.term_type,
        "version": term.version,
        "title": term.title,
        "is_required": term.is_required,
        "requires_consent": term.requires_consent,
        "is_active": term.is_active,
        "effective_at": term.effective_at,
        "content_url": f"/terms/{term.term_id}",
        "is_draft": term.is_draft,
    }
    if detail:
        data["content"] = term.content
    return data


class TermsService:
    def __init__(self):
        self.repo = TermsRepository()

    async def list_terms(self):
        return [term_data(term) for term in await self.repo.current()]

    async def detail(self, term_id):
        term = await self.repo.get(term_id)
        if term is None:
            raise LookupError("약관을 찾을 수 없습니다.")
        return term_data(term, detail=True)
