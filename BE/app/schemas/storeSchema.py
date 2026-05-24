from pydantic import BaseModel
from typing import List, Dict, Optional

# 💡 기본 스토어 목록용 데이터 (아이템 1개)
class StoreItemDTO(BaseModel):
    item_id: int
    item_name: Optional[str]
    price: Optional[int]
    image_url: Optional[str]

# 💡 카테고리별로 묶은 기본 스토어 목록 최종 응답
class StoreListResponse(BaseModel):
    message: str
    # "다이어리": [...], "악세서리": [...], "기타": [...] 형태로 반환
    result: Dict[str, List[StoreItemDTO]] 

# 💡 제품 상세 페이지용 데이터
class ItemDetailDTO(BaseModel):
    item_id: int
    item_name: Optional[str]
    headline: Optional[str]
    description: Optional[str]
    price: Optional[int]
    image_url: Optional[str]

class ItemDetailResponse(BaseModel):
    message: str
    result: ItemDetailDTO