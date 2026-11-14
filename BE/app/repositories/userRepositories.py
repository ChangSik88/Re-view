from app.core.db import db
from prisma.models import User

class UserRepository:
    async def find_by_id(self, account_id: str) -> User:
        # 특정 ID를 가진 유저가 있는지 조회
        return await db.user.find_first(where={'login_id': account_id})

    async def create_user(self, data: dict) -> User:
        # 유저 데이터를 실제로 DB에 저장
        return await db.user.create(data=data)
    
    async def delete_user_with_data(self, user_id: int) -> list[str]:
        # FK가 RESTRICT인 구매·배송·결제·문의·탈퇴이력을 먼저 지운 뒤 유저를 지운다.
        # 채팅방·메시지·이미지·토큰 등은 users 삭제 시 CASCADE로 함께 삭제된다.
        # 파일 정리는 서비스 계층 책임이므로 지우기 전에 이미지 URL을 확보해 반환한다.
        images = await db.chatimage.find_many(where={"ChatRoom": {"is": {"user_id": user_id}}})
        image_urls = [img.image_url for img in images if img.image_url]
        async with db.tx() as tx:
            purchase = {"Purchase": {"is": {"user_id": user_id}}}
            await tx.shipment.delete_many(where=purchase)
            await tx.payment.delete_many(where=purchase)
            await tx.diaryentry.delete_many(where=purchase)
            await tx.purchase.delete_many(where={"user_id": user_id})
            await tx.customerinquiry.delete_many(where={"user_id": user_id})
            await tx.userwithdrawal.delete_many(where={"user_id": user_id})
            await tx.user.delete(where={"user_id": user_id})
        return image_urls

    async def get_user_by_username(self, userAccount: str):
        # Prisma를 이용해 아이디로 유저를 검색합니다.
        # (테이블 스키마에 따라 db.user 부분은 달라질 수 있습니다)
        return await db.user.find_unique(
            where={"login_id": userAccount}
        )