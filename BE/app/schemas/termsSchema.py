from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class TermData(BaseModel):
    term_id: int
    term_type: str
    version: str
    title: str
    is_required: bool
    requires_consent: bool
    is_active: bool
    effective_at: datetime
    content_url: Optional[str]
    is_draft: bool


class TermDetail(TermData):
    content: Optional[str]


class TermsResponse(BaseModel):
    result: list[TermData]


class TermResponse(BaseModel):
    result: TermDetail
