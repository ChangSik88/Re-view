"""상점 카테고리·아이템 초기 데이터 투입.

DB를 새로 만들면 items/item_images/categories가 비어 상점 화면이 빈 목록으로 뜬다.
마이그레이션에는 INSERT가 없으므로 이 스크립트로 채운다.

실행 (BE/에서, 루트 venv 활성화 후):
    python seed_store.py

이미 있는 행은 건너뛰므로 여러 번 실행해도 안전하다.
"""

import asyncio

from dotenv import load_dotenv

load_dotenv()

from app.core.db import db

# 이미지는 app/static/storeImages/ 아래 git 추적 파일이라 재배포해도 유지된다.
# FE의 Api.imageUrl()은 상대경로를 절대경로로 바꿔주지 않으므로 절대 URL로 넣는다.
BASE_URL = "https://re-view-uxww.onrender.com"

# storeService.get_store_list()가 이 세 이름으로 섹션을 가른다.
CATEGORIES = ["다이어리", "악세서리", "기타"]

ITEMS = [
    {
        "category": "다이어리",
        "item_name": "드림 다이어리",
        "headline": "꿈을 기록하는 다이어리",
        "description": "매일의 꿈과 하루를 담는 기본 다이어리입니다.",
        "price": 1000,
        "image": "storeImages/diary/dream_diary.png",
    },
    {
        "category": "악세서리",
        "item_name": "드림 캐처",
        "headline": "좋은 꿈을 부르는 장식",
        "description": "머리맡에 두면 좋은 꿈이 찾아온다는 드림 캐처입니다.",
        "price": 1500,
        "image": "storeImages/accessory/dream_catcher.png",
    },
]


async def main():
    await db.connect()

    category_ids = {}
    for name in CATEGORIES:
        category = await db.category.find_first(where={"name": name})
        if category is None:
            category = await db.category.create(data={"name": name})
            print(f"카테고리 생성: {name}")
        category_ids[name] = category.category_id

    for item_spec in ITEMS:
        if await db.item.find_first(where={"item_name": item_spec["item_name"]}):
            print(f"아이템 존재, 건너뜀: {item_spec['item_name']}")
            continue

        item = await db.item.create(
            data={
                "category_id": category_ids[item_spec["category"]],
                "item_name": item_spec["item_name"],
                "headline": item_spec["headline"],
                "description": item_spec["description"],
                "price": item_spec["price"],
            }
        )
        await db.itemimage.create(
            data={
                "item_id": item.item_id,
                "image_url": f"{BASE_URL}/static/{item_spec['image']}",
                "sort_order": 0,
            }
        )
        print(f"아이템 생성: {item_spec['item_name']}")

    await db.disconnect()


asyncio.run(main())
