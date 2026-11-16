import json

from app.core.db import db


class ResearchRepository:
    async def store(self, tx, user_id, sanitized_payload, source_created_at):
        # DB에서 5년을 계산해 윤년을 포함한 만료일을 정한다.
        return await tx.query_raw('''
                INSERT INTO research_samples (user_id, payload, source_created_at, expires_at)
                SELECT $1, $2::jsonb, $3::timestamptz, $3::timestamptz + INTERVAL '5 years'
                WHERE $3::timestamptz <= CURRENT_TIMESTAMP
                  AND $3::timestamptz + INTERVAL '5 years' > CURRENT_TIMESTAMP
                RETURNING sample_id
        ''', user_id, json.dumps(sanitized_payload, ensure_ascii=False), source_created_at)

    async def eligible(self):
        """향후 학습 작업이 사용할 후보. 실행 직전에도 현재 동의를 확인해야 한다."""
        return await db.query_raw('''
            SELECT s.* FROM research_samples s
            WHERE s.expires_at > CURRENT_TIMESTAMP
              AND NOT EXISTS (SELECT 1 FROM user_withdrawals w WHERE w.user_id = s.user_id)
              AND EXISTS (
                SELECT 1 FROM user_consents c
                JOIN terms t ON t.term_id = c.term_id
                WHERE c.user_id = s.user_id AND c.is_agreed AND c.revoked_at IS NULL
                  AND t.term_type = 'research' AND t.is_active AND t.requires_consent
                  AND t.effective_at <= CURRENT_TIMESTAMP
                  AND c.consent_id = (
                    SELECT c2.consent_id FROM user_consents c2 JOIN terms t2 ON t2.term_id = c2.term_id
                    WHERE c2.user_id = s.user_id AND t2.term_type = 'research'
                    ORDER BY c2.consent_id DESC LIMIT 1
                  )
                  AND t.term_id = (
                    SELECT term_id FROM terms WHERE term_type = 'research' AND is_active
                    AND effective_at <= CURRENT_TIMESTAMP ORDER BY effective_at DESC, term_id DESC LIMIT 1
                  )
              )
        ''')
