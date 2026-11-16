from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, StrictBool, field_validator

from app.schemas.termsSchema import TermData


class ConsentChoice(BaseModel):
    model_config = ConfigDict(extra="forbid")
    term_id: int = Field(gt=0)
    is_agreed: StrictBool


class ConsentChanges(BaseModel):
    model_config = ConfigDict(extra="forbid")
    consents: list[ConsentChoice] = Field(min_length=1, max_length=50)

    @field_validator("consents")
    @classmethod
    def unique_terms(cls, choices):
        ids = [choice.term_id for choice in choices]
        if len(ids) != len(set(ids)):
            raise ValueError("동일 약관을 중복 지정할 수 없습니다.")
        return choices


class ConsentData(TermData):
    is_agreed: bool
    decided_at: Optional[datetime]
    revoked_at: Optional[datetime]


class ConsentResponse(BaseModel):
    result: list[ConsentData]
