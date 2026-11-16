from fastapi import APIRouter, HTTPException

from app.schemas.termsSchema import TermResponse, TermsResponse
from app.services.termsService import TermsService

router = APIRouter()
service = TermsService()


@router.get("", response_model=TermsResponse)
async def list_terms():
    return {"result": await service.list_terms()}


@router.get("/{term_id}", response_model=TermResponse)
async def get_term(term_id: int):
    try:
        return {"result": await service.detail(term_id)}
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
