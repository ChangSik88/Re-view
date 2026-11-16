from datetime import datetime, timedelta, timezone
from contextlib import asynccontextmanager

from app.core.db import db
from prisma.models import User
from app.repositories.consentRepository import ConsentRepository

class UserRepository:
    async def find_by_id(self, account_id: str) -> User:
        # 특정 ID를 가진 유저가 있는지 조회
        return await db.user.find_first(where={'login_id': account_id})

    async def create_user(self, data: dict, client=None) -> User:
        # 유저 데이터를 실제로 DB에 저장
        return await (client or db).user.create(data=data)
    
    async def get_user_by_username(self, userAccount: str):
        # Prisma를 이용해 아이디로 유저를 검색합니다.
        # (테이블 스키마에 따라 db.user 부분은 달라질 수 있습니다)
        return await db.user.find_unique(
            where={"login_id": userAccount}
        )

    async def is_active(self, user_id: int):
        return await db.user.find_first(where={
            "user_id": user_id, "UserWithdrawal": {"none": {}}
        }) is not None

    async def token_is_active(self, user_id: int, auth_version: int):
        return await db.user.find_first(where={
            "user_id": user_id,
            "auth_version": auth_version,
            "UserWithdrawal": {"none": {}},
        }) is not None

    async def profile(self, user_id: int):
        return await db.user.find_unique(where={"user_id": user_id})

    async def update_profile(self, user_id: int, data: dict):
        return await db.user.update(where={"user_id": user_id}, data=data)

    async def withdraw(self, user_id: int):
        async with db.tx() as tx:
            await tx.query_raw('SELECT user_id FROM users WHERE user_id = $1 FOR UPDATE', user_id)
            existing = await tx.userwithdrawal.find_first(where={"user_id": user_id})
            if not existing:
                withdrawn_at = datetime.now(timezone.utc)
                await tx.userwithdrawal.create(data={
                    "user_id": user_id,
                    "withdrawn_at": withdrawn_at,
                    "purge_scheduled_at": withdrawn_at + timedelta(days=30),
                })
                await tx.user.update(where={"user_id": user_id}, data={"auth_version": {"increment": 1}})
                await ConsentRepository().revoke_optional(tx, user_id)

    async def restore(self, user_id: int):
        async with db.tx() as tx:
            locked = await tx.query_raw('SELECT user_id FROM users WHERE user_id = $1 FOR UPDATE', user_id)
            if not locked:
                return False
            withdrawals = await tx.userwithdrawal.find_many(where={"user_id": user_id})
            now = datetime.now(timezone.utc)
            if not withdrawals or any(
                (row.purge_scheduled_at or row.withdrawn_at + timedelta(days=30)) <= now
                for row in withdrawals
            ):
                return False
            await tx.userwithdrawal.delete_many(where={"user_id": user_id})
            # 이전 버전에서 탈퇴한 회원의 과거 토큰도 복구 후 다시 유효해지지 않는다.
            await tx.user.update(where={"user_id": user_id}, data={"auth_version": {"increment": 1}})
            return True

    async def expired_user_ids(self):
        # 이전 버전에서 탈퇴한 계정에도 원래 탈퇴일 기준으로 정책을 적용한다.
        await db.execute_raw('''
            UPDATE user_withdrawals
            SET purge_scheduled_at = withdrawn_at + INTERVAL '30 days'
            WHERE purge_scheduled_at IS NULL
        ''')
        return await db.query_raw('''
            SELECT DISTINCT user_id FROM user_withdrawals
            WHERE purge_scheduled_at <= CURRENT_TIMESTAMP
        ''')
    @asynccontextmanager
    async def expired_account(self, user_id):
        async with db.tx(timeout=timedelta(seconds=60)) as tx:
            # 복구와 삭제가 같은 사용자 행을 잠가 동시에 완료되지 않도록 한다.
            locked = await tx.query_raw('''
                    SELECT user_id FROM users
                    WHERE user_id = $1 AND EXISTS (
                        SELECT 1 FROM user_withdrawals
                        WHERE user_withdrawals.user_id = users.user_id
                          AND purge_scheduled_at <= CURRENT_TIMESTAMP
                    )
                    FOR UPDATE SKIP LOCKED
            ''', user_id)
            if not locked:
                yield None
                return
            images = await tx.query_raw('''
                    SELECT image_url FROM chat_images
                    JOIN chat_rooms USING (room_id) WHERE user_id = $1
            ''', user_id)
            yield tx, [image["image_url"] for image in images]

    async def delete_expired_account(self, tx, user_id):
        # 거래 보존은 사용자 FK 없이 격리한다. 비밀번호·꿈·연구 데이터는 복사하지 않는다.
        await tx.execute_raw('''
            INSERT INTO retained_records (source_type, source_id, payload, expires_at)
            SELECT 'purchase', p.purchase_id,
                jsonb_build_object(
                    'login_id', u.login_id, 'purchase', to_jsonb(p),
                    'payments', (SELECT jsonb_agg(to_jsonb(pay)) FROM payments pay WHERE pay.purchase_id = p.purchase_id),
                    'shipments', (SELECT jsonb_agg(jsonb_build_object('shipment', to_jsonb(s), 'address', to_jsonb(a) - 'is_default' - 'created_at'))
                        FROM shipments s JOIN user_addresses a USING (address_id) WHERE s.purchase_id = p.purchase_id)
                ),
                GREATEST(p.created_at, p.bought_at,
                    (SELECT MAX(GREATEST(paid_at, refunded_at, created_at)) FROM payments WHERE purchase_id = p.purchase_id),
                    (SELECT MAX(GREATEST(delivered_at, shipped_at)) FROM shipments WHERE purchase_id = p.purchase_id)
                ) + INTERVAL '5 years'
            FROM purchases p JOIN users u USING (user_id)
            WHERE p.user_id = $1 AND (p.is_bought OR EXISTS (SELECT 1 FROM payments WHERE purchase_id = p.purchase_id))
            ON CONFLICT (source_type, source_id) DO NOTHING
        ''', user_id)
        await tx.execute_raw('''
            INSERT INTO retained_records (source_type, source_id, payload, expires_at)
            SELECT 'inquiry', i.inquiry_id,
                jsonb_build_object('login_id', u.login_id, 'inquiry', to_jsonb(i)),
                GREATEST(i.created_at, i.answered_at) + INTERVAL '3 years'
            FROM customer_inquiries i JOIN users u USING (user_id)
            WHERE i.user_id = $1
            ON CONFLICT (source_type, source_id) DO NOTHING
        ''', user_id)
        # 구매를 참조하는 Restrict 관계부터 삭제한다.
        await tx.execute_raw('''
                    DELETE FROM payments WHERE purchase_id IN (
                        SELECT purchase_id FROM purchases WHERE user_id = $1
                    )
        ''', user_id)
        await tx.execute_raw('''
                    DELETE FROM shipments WHERE purchase_id IN (
                        SELECT purchase_id FROM purchases WHERE user_id = $1
                    ) OR address_id IN (
                        SELECT address_id FROM user_addresses WHERE user_id = $1
                    )
        ''', user_id)
        await tx.execute_raw('''
                    DELETE FROM diary_entries WHERE purchase_id IN (
                        SELECT purchase_id FROM purchases WHERE user_id = $1
                    )
        ''', user_id)
        await tx.purchase.delete_many(where={"user_id": user_id})
        await tx.customerinquiry.delete_many(where={"user_id": user_id})
        await tx.userwithdrawal.delete_many(where={"user_id": user_id})
        await tx.user.delete(where={"user_id": user_id})

    async def cleanup_retention(self):
        now = datetime.now(timezone.utc)
        await db.researchsample.delete_many(where={"expires_at": {"lte": now}})
        await db.retainedrecord.delete_many(where={"expires_at": {"lte": now}})
        # 동의 버전 변경·기존 탈퇴 데이터 등으로 이용 근거가 사라진 사본도 제거한다.
        await db.execute_raw('''
            DELETE FROM research_samples s WHERE NOT EXISTS (
                SELECT 1 FROM user_consents c JOIN terms t ON t.term_id = c.term_id
                WHERE c.user_id = s.user_id AND c.is_agreed AND c.revoked_at IS NULL
                  AND t.term_type = 'research' AND t.is_active AND t.requires_consent
                  AND t.term_id = (SELECT term_id FROM terms WHERE term_type = 'research' AND is_active
                      AND effective_at <= CURRENT_TIMESTAMP ORDER BY effective_at DESC, term_id DESC LIMIT 1)
                  AND c.consent_id = (SELECT c2.consent_id FROM user_consents c2 JOIN terms t2 ON t2.term_id = c2.term_id
                      WHERE c2.user_id = s.user_id AND t2.term_type = 'research'
                      ORDER BY c2.consent_id DESC LIMIT 1)
            ) OR EXISTS (SELECT 1 FROM user_withdrawals w WHERE w.user_id = s.user_id)
        ''')
