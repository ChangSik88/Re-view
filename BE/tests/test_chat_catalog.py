"""Offline contract tests: real prompt/parser/catalog, no network model calls."""
import json
import os
import unittest
from unittest.mock import patch

os.environ.setdefault("GOOGLE_API_KEY", "offline-test-key")

from langchain_core.runnables import RunnableLambda
from app.core.ai import dreamKeywordHarness as catalog
from app.core.ai import langchainManager as manager


class ChatCatalogTests(unittest.IsolatedAsyncioTestCase):
    def test_catalog_resolves_only_two_unique_exact_keys(self):
        keys = list(catalog._load_keyword_cards())
        self.assertEqual(len(keys), 300)
        cards = catalog.resolve_keyword_cards(["없는 키워드", keys[0], keys[0], keys[1], keys[2]])
        self.assertEqual([c["keyword"] for c in cards], keys[:2])

    async def test_morning_reply_uses_catalog_and_preserves_details(self):
        key = next(iter(catalog._load_keyword_cards()))
        prompts = []
        def extract(prompt):
            self.assertIn("앞서 말한 꿈", prompt.to_string())
            return json.dumps({"matched_keywords": [key]}, ensure_ascii=False)
        def reply(prompt):
            prompts.append(prompt.to_string())
            return json.dumps({"theme": "꿈", "vibe": "차분함", "suggested_feelings": ["편안"],
                "ai_reply": "이 꿈은 이렇게 해석할 수 있어요.",
                "story_details": {"place": "학교", "characters": ["친구"]}}, ensure_ascii=False)
        with patch.object(catalog, "llm", RunnableLambda(extract)), patch.object(manager, "llm", RunnableLambda(reply)):
            result = await manager.analyze_dream_chat("USER: 앞서 말한 꿈", "그건 어떤 의미야?", "Morning")
        card = catalog._load_keyword_cards()[key]
        self.assertIn(card["positive_interpretation"], prompts[0])
        self.assertIn(card["advice"], prompts[0])
        self.assertEqual(result.story_details.place, "학교")
        self.assertEqual(result.story_details.characters, ["친구"])

    async def test_no_match_keeps_empty_evidence(self):
        with patch.object(catalog, "llm", RunnableLambda(lambda _: '{"matched_keywords": ["invented"]}')):
            self.assertEqual(await catalog.get_chat_catalog_context("", "안녕"), "[]")

    async def test_night_does_not_call_dream_catalog(self):
        def fail(_):
            self.fail("Night routine must not query dream catalog")
        reply = json.dumps({"theme": "하루", "vibe": "차분함", "suggested_feelings": [], "ai_reply": "오늘은 어땠나요?"})
        with patch.object(catalog, "llm", RunnableLambda(fail)), patch.object(manager, "llm", RunnableLambda(lambda _: reply)):
            result = await manager.analyze_dream_chat("", "안녕", "Night")
        self.assertEqual(result.ai_reply, "오늘은 어땠나요?")


if __name__ == "__main__":
    unittest.main()
