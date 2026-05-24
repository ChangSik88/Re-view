from fastapi import APIRouter, Depends, HTTPException
from app.api.dependencies import get_current_user_id
from app.schemas.reportSchema import ReportResponse
from app.repositories.reportRepository import ReportRepository
from app.core.ai.reportManager import ReportManager
from app.services.reportService import ReportService

router = APIRouter()

report_service = ReportService()

@router.post("/analyze", response_model=ReportResponse)
async def create_dream_report(
    user_id: int = Depends(get_current_user_id)
):
    try:
        # 서비스 계층 호출
        report_data = await report_service.generate_and_save_report(user_id)
        
        return {
            "message": "꿈 패턴 분석 완료 및 저장 성공",
            "result": report_data
        }
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"리포트 생성 중 오류 발생: {str(e)}")