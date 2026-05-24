from fastapi import APIRouter, HTTPException
from app.schemas.storeSchema import StoreListResponse,ItemDetailResponse
from app.services.storeService import StoreService
# 무진님 환경에 맞게 스키마와 서비스 객체 임포트
# from app.schemas.storeSchema import StoreListResponse, ItemDetailResponse
# from app.services import store_service

router = APIRouter()
store_service = StoreService()

# 1. 기본 스토어 창 조회 API
@router.get("/list", response_model=StoreListResponse)
async def get_store_items():
    try:
        grouped_items = await store_service.get_store_list()
        
        return {
            "message": "스토어 목록 조회 성공",
            "result": grouped_items
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"스토어 목록 조회 중 오류 발생: {str(e)}")


# 2. 제품 상세 페이지 조회 API
@router.get("/detail/{item_id}", response_model=ItemDetailResponse)
async def get_item_detail(item_id: int):
    try:
        item_detail = await store_service.get_item_detail(item_id)
        
        return {
            "message": "상품 상세 조회 성공",
            "result": item_detail
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e)) # 없는 상품일 때 404
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"상품 상세 조회 중 오류 발생: {str(e)}")