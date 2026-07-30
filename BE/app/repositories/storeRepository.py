from app.core.db import db 

class StoreRepository:
    
    # 1. 모든 아이템 목록 가져오기 (카테고리 분류 전)
    async def get_all_items(self):
        return await db.item.find_many(
            include={
                "ItemImage": True,  # 연결된 이미지 URL 데이터도 함께 가져옵니다!
                "Category": True
            }
        )

    # 2. 특정 아이템 상세 정보 가져오기
    async def get_item_by_id(self, item_id: int):
        return await db.item.find_unique(
            where={
                "item_id": item_id
            },
            include={
                "ItemImage": True,
                "Category": True
            }
        )