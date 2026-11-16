from fastapi import APIRouter, Depends, HTTPException

from app.api.dependencies import get_current_user_id
from app.schemas.consentSchema import ConsentChanges, ConsentResponse
from app.services.consentService import ConsentConflict, ConsentService

router = APIRouter()
service = ConsentService()


@router.get("/me/consents", response_model=ConsentResponse)
async def get_consents(user_id: int = Depends(get_current_user_id)):
    return {"result": await service.status(user_id)}


@router.patch("/me/consents", response_model=ConsentResponse)
async def change_consents(body: ConsentChanges, user_id: int = Depends(get_current_user_id)):
    try:
        return {"result": await service.change(user_id, [choice.model_dump() for choice in body.consents])}
    except ConsentConflict as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
