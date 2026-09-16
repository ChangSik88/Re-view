from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse
from app.schemas.demoSchema import DemoInterpretRequest, DemoInterpretResponse, DemoRankingResponse
from app.services.demoService import DemoService, DemoRateLimitError, DemoUnavailableError

router = APIRouter()
demo_service = DemoService()


def _get_visitor_id(request: Request) -> str:
    # 정상 경로: 클라이언트(app.js)가 localStorage에 만든 익명 ID를 헤더로 보낸다(ADR 0002).
    # IP가 아니라 이 값으로 방문자를 구분해야 공유 와이파이·CGNAT 뒤 오탐 차단이 없다.
    header_id = request.headers.get("x-demo-visitor-id")
    if header_id:
        return header_id.strip()[:100]  # 방어적 길이 제한. 카운터 dict 키로만 쓰이는 값이다.

    # 폴백 경로: JS 비활성·localStorage 차단·API 직접 호출처럼 헤더가 없는 드문 경우.
    # Render는 프록시 뒤에 있어 request.client.host는 방문자가 아니라 내부 프록시 IP다.
    forwarded_for = request.headers.get("x-forwarded-for")
    fallback_ip = forwarded_for.split(",")[0].strip() if forwarded_for else (
        request.client.host if request.client else "unknown"
    )
    # 정상 브라우저 트래픽은 이 분기를 안 타므로, 매 요청 IP를 로그에 남기던 이전 방식보다
    # "방문자 IP를 저장하지 않는다"(스펙 3.7)는 원칙과의 긴장이 훨씬 적다.
    print(f"[demo] 방문자 ID 헤더 없음, IP로 폴백: {fallback_ip!r}")
    return fallback_ip


@router.post("/interpret", response_model=DemoInterpretResponse)
async def interpret_dream(body: DemoInterpretRequest, request: Request):
    visitor_id = _get_visitor_id(request)
    try:
        return await demo_service.interpret(body.dream, visitor_id)
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
