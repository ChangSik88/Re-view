from prisma.models import ChatRoom, ChatMessage
from app.core.db import db # main.py에서 연결한 prisma db 객체
from datetime import datetime
class ChatRepository:
    # 1. 새로운 채팅방 생성
    async def create_session(self, user_id: int,routine_type:str):
        # 채팅방을 만들고 방 번호(객체)를 반환합니다.
        return await db.chatroom.create(
            data={"user_id": user_id,
                  "routine_type": routine_type}
        )

    # 2. 메시지 저장 (유저 메시지 & AI 메시지 공용)
    async def save_message(self, room_id: int, role: str, content: str):
        # role은 "USER" 또는 "AI" 로 구분하여 저장
        return await db.chatmessage.create(
            data={
                "room_id": room_id,
                "role": role,
                "content": content
            }
        )

    # 3. 과거 대화 내역 불러오기 (LangChain에게 문맥을 주기 위함)
    async def get_chat_history(self, room_id: int):
        # 특정 방의 메시지를 시간순(오름차순)으로 전부 가져옵니다.
        return await db.chatmessage.find_many(
            where={"room_id": room_id},
            order={"created_at": "asc"}
        )

    async def update_session_with_diary(self, room_id: int, title: str, content: str, tags: str, vector: list[float]):
        # 일기 본문 저장과 벡터 갱신을 하나의 트랜잭션으로 묶어 부분 저장(반쪽 일기)을 방지
        vector_str = str(vector)
        async with db.tx() as tx:
            await tx.chatroom.update(
                where={
                    "room_id": room_id
                },
                data={
                    "title": title,
                    "content": content,
                    "tags": tags,
                })
            await tx.execute_raw(
                'UPDATE "chat_rooms" SET content_vector = $1::vector WHERE room_id = $2',
                vector_str,
                room_id
            )

        return True
    #이미지 URL을 저장
    async def save_chat_image(self, room_id: int, image_url: str):
        return await db.chatimage.create(
            data={
                "room_id": room_id,
                "image_url": image_url,
            }
        )



    #채팅방(세션) 단건 조회 - 루틴타입 확인 및 소유권 검증에 사용
    async def get_session(self, room_id: int):
        return await db.chatroom.find_unique(
            where={"room_id": room_id}
        )

    # 즐겨찾기 상태 명시적 설정
    async def set_marked(self, room_id: int, is_marked: bool):
        return await db.chatroom.update(
            where={"room_id": room_id},
            data={"is_marked": is_marked}
        )

    # 세션 삭제: FK가 NoAction이라 자식(메시지/이미지)을 먼저 지워야 부모 삭제가 가능하다.
    # 파일 정리는 서비스 계층 책임이므로, 지우기 전에 이미지 URL을 먼저 확보해 반환한다.
    async def delete_session(self, room_id: int) -> list[str]:
        images = await db.chatimage.find_many(where={"room_id": room_id})
        image_urls = [img.image_url for img in images if img.image_url]

        async with db.tx() as tx:
            await tx.chatmessage.delete_many(where={"room_id": room_id})
            await tx.chatimage.delete_many(where={"room_id": room_id})
            await tx.chatroom.delete(where={"room_id": room_id})

        return image_urls