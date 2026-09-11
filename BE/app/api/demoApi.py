from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse
from app.schemas.demoSchema import DemoInterpretRequest, DemoInterpretResponse, DemoRankingResponse
from app.services.demoService import DemoService, DemoRateLimitError, DemoUnavailableError

router = APIRouter()
demo_service = DemoService()


def _get_client_ip(request: Request) -> str:
    # Render는 프록시 뒤에 있어 request.client.host는 방문자가 아니라 내부 프록시 IP다.
    # 아래 print는 배포 후 실제 헤더 순서를 확인하기 위한 1회성 로그다(스펙 3.4 "구현 시 반드시 검증할 것").
    # 확인 후에도 남겨둘지, 파싱 로직을 교정할지는 로그 결과를 보고 결정한다.
    forwarded_for = request.headers.get("x-forwarded-for")
    print(f"[demo] X-Forwarded-For={forwarded_for!r} client.host={request.client.host if request.client else None}")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


@router.post("/interpret", response_model=DemoInterpretResponse)
async def interpret_dream(body: DemoInterpretRequest, request: Request):
    client_ip = _get_client_ip(request)
    try:
        return await demo_service.interpret(body.dream, client_ip)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except DemoRateLimitError as e:
        # 스펙 3.3의 429 바디는 {"detail", "reason"}이 평평한 구조라 HTTPException(dict detail)로는
        # {"detail": {"detail":..., "reason":...}}처럼 중첩되어 버린다. JSONResponse로 직접 반환한다.
        return JSONResponse(
            status_code=429,
            content={"detail": "지금은 더 해몽할 수 없어요.", "reason": e.reason},
        )
    except DemoUnavailableError:
        raise HTTPException(status_code=503, detail="지금은 해몽을 불러올 수 없어요.")


@router.get("/ranking", response_model=DemoRankingResponse)
async def get_ranking():
    return await demo_service.get_ranking()
