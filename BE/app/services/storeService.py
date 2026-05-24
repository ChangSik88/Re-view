from app.repositories.storeRepository import StoreRepository

class StoreService:
    def __init__(self):
        self.store_repo = StoreRepository()

    # 1. 기본 스토어 창 데이터 가공
    async def get_store_list(self):
        raw_items = await self.store_repo.get_all_items()
        
        # 프론트가 섹션별로 그리기 편하게 카테고리별 빈 리스트를 준비합니다.
        categorized_items = {
            "다이어리": [],
            "악세서리": [],
            "기타": []
        }

        for item in raw_items:
            # 💡 1:N 관계이므로 리스트로 옵니다. 첫 번째 이미지가 있다면 꺼내고, 없으면 None 반환
            img_url = item.Item_Url[0].image_url if item.Item_Url else None

            item_data = {
                "item_id": item.item_id,
                "item_name": item.item_name,
                "price": item.price,
                "image_url": img_url
            }

            # 아이템의 카테고리를 확인하고 알맞은 그룹에 넣습니다. (분류가 안 되어있으면 '기타'로)
            category = item.category if item.category in categorized_items else "기타"
            categorized_items[category].append(item_data)

        return categorized_items

    # 2. 제품 상세 페이지 데이터 가공
    async def get_item_detail(self, item_id: int):
        item = await self.store_repo.get_item_by_id(item_id)
        
        if not item:
            raise ValueError("해당 상품을 찾을 수 없습니다.")

        # 상세 페이지에서도 이미지를 안전하게 추출합니다.
        img_url = item.Item_Url[0].image_url if item.Item_Url else None

        return {
            "item_id": item.item_id,
            "item_name": item.item_name,
            "headline": item.headline,
            "description": item.description,
            "price": item.price,
            "image_url": img_url
        }