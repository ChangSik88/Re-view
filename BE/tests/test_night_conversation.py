"""Offline contracts for Night prompt routing, structured output and fact-only reports."""
import importlib
import json
import sys
import unittest
from types import ModuleType
from unittest.mock import patch
from langchain_core.runnables import RunnableLambda
from app.schemas.chatSchema import NightAnalysisResponse

# Avoid credentials/network initialization while exercising the actual chains/parser.
provider = ModuleType('langchain_google_genai')
provider.ChatGoogleGenerativeAI = lambda **kwargs: RunnableLambda(lambda _: '')
provider.GoogleGenerativeAIEmbeddings = lambda **kwargs: object()
with patch.dict(sys.modules, {'langchain_google_genai': provider}):
    manager = importlib.import_module('app.core.ai.langchainManager')

class NightConversationTests(unittest.IsolatedAsyncioTestCase):
    async def test_night_passes_history_and_uses_non_speculative_schema(self):
        captured = []
        def reply(prompt):
            captured.append(prompt.to_messages())
            return json.dumps({'ai_reply':'그때 어떤 기분이 들었어요?',
                'story_details':{'place':'카페','characters':['친구'], 'situation':'친구가 말을 끊어서 다툼'}}, ensure_ascii=False)
        with patch.object(manager, 'llm', RunnableLambda(reply)):
            result = await manager.analyze_dream_chat('USER: 오늘 친구랑 싸웠어.\nAI: 무슨 일이 있었어요?', '카페에서 내 말을 자꾸 끊더라고.', 'Night')
        self.assertIsInstance(result, NightAnalysisResponse)
        self.assertEqual(result.story_details.place,'카페')
        self.assertEqual(result.story_details.characters,['친구'])
        self.assertEqual(result.suggested_feelings,[])
        self.assertEqual(result.story_details.emotions,'')
        system, user = captured[0]
        self.assertIn('질문은 최대 하나',system.content)
        self.assertIn('감정 세 개를 채울 필요가 없습니다',system.content)
        self.assertNotIn('유저가 느꼈을 법한 핵심 감정 키워드 3개',system.content)
        self.assertIn('USER: 오늘 친구랑 싸웠어.',user.content)
        self.assertEqual(user.content.count('카페에서 내 말을 자꾸 끊더라고.'),1)

    async def test_morning_keeps_own_prompt_and_parser(self):
        def reply(prompt):
            system = prompt.to_messages()[0].content
            self.assertIn('전통 해몽 전문가',system)
            self.assertNotIn('나이트루틴 최우선',system)
            return json.dumps({'theme':'꿈','vibe':'차분','suggested_feelings':[], 'ai_reply':'꿈 이야기를 들려주세요.'})
        with patch.object(manager,'llm',RunnableLambda(reply)):
            result = await manager.analyze_dream_chat('', '안녕', 'Morning')
        self.assertNotIsInstance(result,NightAnalysisResponse)

    def test_prompt_covers_skips_corrections_and_ongoing_discomfort(self):
        prompt = manager.NIGHT_CHAT_PROMPT
        for rule in ['질문은 최대 하나', '사용자의 정정', '재질문하지 마세요', '모든 칸은 선택사항',
                     'AI의 과거 발언은 사실의 근거가 아닙니다', '신체 증상은 감정으로 바꾸지 마세요',
                     '이미 저장했다고 말하지 마세요', '원인·진단·회복을 추측']:
            self.assertIn(rule,prompt)

    async def test_report_preserves_unknowns_and_does_not_invent_resolution(self):
        def reply(prompt):
            system = prompt.to_messages()[0].content
            self.assertIn('AI가 질문하거나 추측한 내용',system)
            self.assertIn('긍정적인 결말',system)
            return json.dumps({'title':'친구와의 대화','content':'친구와 다퉜다.','tags':[], 'image_prompt':'crayon drawing'})
        with patch.object(manager,'llm',RunnableLambda(reply)):
            result = await manager.generate_diary_content('USER: 친구와 싸웠어', [], 'Night')
        self.assertEqual(result.content,'친구와 다퉜다.')

if __name__ == '__main__': unittest.main()
