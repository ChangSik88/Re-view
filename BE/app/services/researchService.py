from app.core.db import db
from app.repositories.consentRepository import ConsentRepository
from app.repositories.researchRepository import ResearchRepository


class ResearchService:
    async def store_sample(self, user_id, sanitized_payload, source_created_at):
        """내부 학습 수집 작업에서 가명처리를 마친 데이터만 전달한다."""
        async with db.tx() as tx:
            locked = await tx.query_raw('SELECT user_id FROM users WHERE user_id = $1 FOR UPDATE', user_id)
            if not locked or not await ConsentRepository().permits(tx, user_id, "research"):
                raise PermissionError("연구 활용에 동의한 활성 계정만 저장할 수 있습니다.")
            rows = await ResearchRepository().store(tx, user_id, sanitized_payload, source_created_at)
            if not rows:
                raise ValueError("원본 생성일이 미래이거나 보유 기간이 지났습니다.")
            return rows[0]["sample_id"]
