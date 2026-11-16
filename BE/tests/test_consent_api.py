"""TEST_DATABASE_URL로 지정한 PostgreSQL의 임시 스키마에서 실행하는 통합 검증.

실행은 BE/에서 python -m unittest discover -s tests -p test_consent_api.py.
pgvector 없이도 계정·약관 관계를 검증하도록 테스트 스키마의 vector 컬럼만 TEXT로 바꾼다.
"""
import asyncio
import ast
from contextlib import asynccontextmanager, suppress
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import secrets
import sys
import unittest
from types import SimpleNamespace
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
from unittest.mock import AsyncMock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


class ConsentApiTest(unittest.TestCase):
    def test_cleanup_lifespan(self):
        async def verify():
            started = asyncio.Event()

            async def purge():
                started.set()

            connection = SimpleNamespace(connect=AsyncMock(), disconnect=AsyncMock(), is_connected=lambda: True)
            cleanup_service = SimpleNamespace(purge_expired_users=AsyncMock(side_effect=purge))
            module = ast.parse((ROOT / "app/main.py").read_text(encoding="utf8"))
            functions = [node for node in module.body if isinstance(node, ast.AsyncFunctionDef)
                         and node.name in {"cleanup_personal_data", "lifespan"}]
            namespace = dict(asyncio=asyncio, asynccontextmanager=asynccontextmanager, suppress=suppress,
                             db=connection, UserService=lambda: cleanup_service, FastAPI=object,
                             logging=__import__("logging"))
            exec(compile(ast.Module(body=functions, type_ignores=[]), "main_lifespan", "exec"), namespace)
            async with namespace["lifespan"](None):
                await asyncio.wait_for(started.wait(), timeout=2)
            connection.disconnect.assert_awaited_once()
            cleanup_service.purge_expired_users.assert_awaited_once()

        asyncio.run(verify())

    @unittest.skipUnless(os.environ.get("TEST_DATABASE_URL"), "TEST_DATABASE_URL is required")
    def test_consent_and_account_lifecycle(self):
        asyncio.run(self.verify_lifecycle())

    async def verify_lifecycle(self):
        schema = "consent_test_" + secrets.token_hex(8)
        url = urlsplit(os.environ["TEST_DATABASE_URL"])
        query = [(key, value) for key, value in parse_qsl(url.query) if key != "schema"]
        os.environ["DATABASE_URL"] = urlunsplit(url._replace(query=urlencode(query + [("schema", schema)])))
        os.environ["JWT_SECRET_KEY"] = secrets.token_hex(32)
        from app.core.db import db
        from app.api import userApi, termsApi, consentApi
        from app.repositories.researchRepository import ResearchRepository
        from app.services.researchService import ResearchService
        from app.repositories.consentRepository import ConsentRepository
        from app.core.security import create_access_token
        from app.services.userServices import UserService
        from fastapi import FastAPI
        from httpx import AsyncClient, ASGITransport

        await db.connect()
        try:
            await db.execute_raw(f'CREATE SCHEMA "{schema}"')
            migrations = ROOT / "prisma/migrations"
            initial = next(migrations.glob("*_init/migration.sql")).read_text(encoding="utf8")
            initial = re.sub(r"CREATE EXTENSION[^;]+;", "", initial)
            initial = re.sub(r"vector\(3072\)", "TEXT", initial, flags=re.I)
            for sql in initial.split(";"):
                if re.search(r"\b(CREATE|ALTER)\b", re.sub(r"--[^\n]*", "", sql)):
                    await db.execute_raw(sql)
            migration = (migrations / "20261116000000_terms_consent_recovery/migration.sql").read_text(encoding="utf8")
            statements = re.findall(r"(?:\$agreement\$.*?\$agreement\$|'(?:''|[^'])*'|[^;])+;", migration, re.S)
            for statement in statements:
                await db.execute_raw(statement.rstrip(";"))

            app = FastAPI()
            app.include_router(userApi.router, prefix="/users")
            app.include_router(consentApi.router, prefix="/users")
            app.include_router(termsApi.router, prefix="/terms")
            async with AsyncClient(transport=ASGITransport(app=app, raise_app_exceptions=False), base_url="http://test") as client:
                async def request(method, path, expected, **kwargs):
                    response = await client.request(method, path, **kwargs)
                    self.assertEqual(response.status_code, expected, f"{method} {path}: {response.text}")
                    return response

                terms = (await request("GET", "/terms", 200)).json()["result"]
                self.assertEqual(len(terms), 5)
                self.assertTrue(all(term["is_draft"] for term in terms))
                by_type = {term["term_type"]: term for term in terms}
                research_id = by_type["research"]["term_id"]
                required = [{"term_id": term["term_id"], "is_agreed": True} for term in terms if term["is_required"]]
                payload = dict(id="consent-test", password="test-password", name="Test", age_over_14_confirmed=True, consents=required)
                detail = (await request("GET", f"/terms/{research_id}", 200)).json()["result"]
                self.assertIn("최대 5년", detail["content"])
                await request("GET", "/terms/999999", 404)
                await request("POST", "/users/signup", 400, json={**payload, "age_over_14_confirmed": False})
                await request("POST", "/users/signup", 422, json={**payload, "consents": required + required})
                await request("POST", "/users/signup", 400, json={**payload, "consents": required[:1]})
                await request("POST", "/users/signup", 409, json={**payload, "consents": required + [{"term_id": 999999, "is_agreed": True}]})
                with patch.object(ConsentRepository, "append", new=AsyncMock(side_effect=RuntimeError("test rollback"))):
                    await request("POST", "/users/signup", 500, json=payload)
                self.assertIsNone(await db.user.find_unique(where={"login_id": payload["id"]}))
                await request("POST", "/users/signup", 200, json=payload)
                await request("POST", "/users/signup", 400, json=payload)
                user = await db.user.find_unique(where={"login_id": payload["id"]})
                self.assertIsNotNone(user.age_confirmed_at)
                self.assertIsNone(user.birth)
                self.assertIsNone(user.gender)
                login = dict(userAccount=payload["id"], password=payload["password"])
                token = (await request("POST", "/users/login", 200, json=login)).json()["access_token"]
                headers = {"Authorization": "Bearer " + token}
                await request("GET", "/users/me", 200, headers=headers)
                await request("PATCH", "/users/me", 200, headers=headers, json={"name": "Changed"})
                await request("PATCH", "/users/me", 422, headers=headers, json={"gender": "male"})

                research = ResearchRepository()
                research_service = ResearchService()
                source_at = datetime.now(timezone.utc)
                with self.assertRaises(PermissionError):
                    await research_service.store_sample(user.user_id, {"topic": "test"}, source_at)
                async def choose(agreed, term_id=None, status=200):
                    term_id = research_id if term_id is None else term_id
                    return await request("PATCH", "/users/me/consents", status, headers=headers,
                        json={"consents": [{"term_id": term_id, "is_agreed": agreed}]})
                await choose(False, required[0]["term_id"], 400)
                await choose(True)
                await research_service.store_sample(user.user_id, {"topic": "sanitized"}, source_at)
                pending = await db.term.find_first(where={"term_type": "marketing"})
                await choose(True, pending.term_id, 409)
                newer = await db.term.create(data={
                    "term_type": "research", "version": "test-next", "title": "New research version",
                    "content": "New terms", "is_required": False, "requires_consent": True,
                    "is_active": True, "is_draft": True, "effective_at": datetime.now(timezone.utc),
                })
                self.assertEqual(len(await research.eligible()), 0)
                await choose(True, research_id, 409)
                research_id = newer.term_id
                await choose(True)
                self.assertEqual(len(await research.eligible()), 1)
                await choose(False)
                self.assertEqual(await db.researchsample.count(), 0)
                self.assertEqual(len(await research.eligible()), 0)
                self.assertGreaterEqual(await db.userconsent.count(where={"user_id": user.user_id}), 4)
                await choose(True)
                await research_service.store_sample(user.user_id, {"topic": "sanitized"}, source_at)

                await request("POST", "/users/restore", 401, json={**login, "password": "wrong"})
                await request("DELETE", "/users/me", 204, headers=headers)
                self.assertEqual(await db.researchsample.count(), 0)
                await request("GET", "/users/me", 401, headers=headers)
                await request("POST", "/users/login", 401, json=login)
                await request("POST", "/users/signup", 400, json=payload)
                restores = await asyncio.gather(client.post("/users/restore", json=login), client.post("/users/restore", json=login))
                self.assertEqual(sorted(response.status_code for response in restores), [200, 409])
                await request("GET", "/users/me", 401, headers=headers)
                old_token = create_access_token(user.user_id)
                await request("GET", "/users/me", 401, headers={"Authorization": "Bearer " + old_token})
                fresh = (await request("POST", "/users/login", 200, json=login)).json()["access_token"]
                headers = {"Authorization": "Bearer " + fresh}
                consents = (await request("GET", "/users/me/consents", 200, headers=headers)).json()["result"]
                self.assertFalse(next(row for row in consents if row["term_type"] == "research")["is_agreed"])

                await choose(True)
                await research_service.store_sample(user.user_id, {"topic": "expired"}, source_at)
                await db.execute_raw("UPDATE research_samples SET expires_at=CURRENT_TIMESTAMP-INTERVAL '1 second'")
                await userApi.user_service.user_repo.cleanup_retention()
                self.assertEqual(await db.researchsample.count(), 0)
                await request("DELETE", "/users/me", 204, headers=headers)
                await db.execute_raw("UPDATE user_withdrawals SET purge_scheduled_at=CURRENT_TIMESTAMP-INTERVAL '1 second'")
                await request("POST", "/users/restore", 409, json=login)
                await db.execute_raw("INSERT INTO categories (name) VALUES ('test')")
                await db.execute_raw("INSERT INTO items (category_id,item_name,price) SELECT category_id,'test',100 FROM categories")
                await db.execute_raw('INSERT INTO purchases (user_id,item_id,is_bought) SELECT $1,item_id,true FROM items', user.user_id)
                await db.execute_raw('INSERT INTO payments (purchase_id,amount) SELECT purchase_id,100 FROM purchases')
                await db.execute_raw("INSERT INTO user_addresses (user_id,recipient_name,phone_number,address_line1) VALUES ($1,'test','000','test')", user.user_id)
                await db.execute_raw('INSERT INTO shipments (purchase_id,address_id) SELECT purchase_id,address_id FROM purchases CROSS JOIN user_addresses')
                await db.execute_raw('INSERT INTO diary_entries (purchase_id,selected_date) SELECT purchase_id,CURRENT_DATE FROM purchases')
                await db.execute_raw("INSERT INTO customer_inquiries (user_id,title,content) VALUES ($1,'test','test')", user.user_id)
                await db.execute_raw('INSERT INTO chat_rooms (user_id) VALUES ($1)', user.user_id)
                await db.execute_raw("INSERT INTO chat_images (room_id,image_url) SELECT room_id,'https://example.invalid/test.png' FROM chat_rooms")
                with patch("app.services.userServices.storage.delete_image", new=AsyncMock(side_effect=RuntimeError("test image retry"))):
                    with self.assertLogs("app.services.userServices", level="ERROR"):
                        self.assertEqual(await UserService().purge_expired_users(), 0)
                self.assertIsNotNone(await db.user.find_unique(where={"user_id": user.user_id}))
                with patch("app.services.userServices.storage.delete_image", new=AsyncMock()):
                    results = await asyncio.gather(UserService().purge_expired_users(), UserService().purge_expired_users())
                self.assertEqual(sum(results), 1)
                self.assertEqual(await db.retainedrecord.count(), 2)
                self.assertEqual(await db.purchase.count(), 0)
                self.assertEqual(await db.chatimage.count(), 0)
                self.assertEqual(await db.userconsent.count(), 0)
                await request("POST", "/users/signup", 200, json=payload)
                await db.execute_raw("UPDATE retained_records SET expires_at=CURRENT_TIMESTAMP-INTERVAL '1 second'")
                await userApi.user_service.user_repo.cleanup_retention()
                self.assertEqual(await db.retainedrecord.count(), 0)
        finally:
            await db.execute_raw(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE')
            await db.disconnect()


if __name__ == "__main__":
    unittest.main()
