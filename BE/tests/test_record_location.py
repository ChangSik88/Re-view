import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch
from pydantic import ValidationError
from app.schemas.chatSessionSchema import RecordLocation
from app.services.chatSessionService import ChatSessionService

class RecordLocationTests(unittest.IsolatedAsyncioTestCase):
    def test_requires_complete_valid_coordinates(self):
        for payload in ({'place_name':'카페'}, {'place_name':' ', 'latitude':37, 'longitude':127},
                        {'place_name':'카페','latitude':91,'longitude':127},
                        {'place_name':'카페','latitude':37,'longitude':float('nan')}):
            with self.assertRaises(ValidationError): RecordLocation(**payload)
        self.assertEqual(RecordLocation().model_dump(), {'place_name':None,'latitude':None,'longitude':None})

    async def test_save_requires_owned_night_report(self):
        service = ChatSessionService()
        repo = service.chat_session_repository
        repo.get_one_session_by_id = AsyncMock(return_value=None)
        repo.set_location = AsyncMock(return_value=1)
        location = RecordLocation(place_name=' 카페 ',latitude=37.3,longitude=126.8)
        with self.assertRaises(LookupError): await service.set_location(7,10,location)
        repo.set_location.assert_not_awaited()
        repo.get_one_session_by_id.return_value = SimpleNamespace(routine_type='Morning',content='dream')
        with self.assertRaises(ValueError): await service.set_location(7,10,location)
        repo.set_location.assert_not_awaited()
        repo.get_one_session_by_id.return_value = SimpleNamespace(routine_type='Night',content='report')
        result = await service.set_location(7,10,location)
        repo.set_location.assert_awaited_once_with(7,10,{'place_name':'카페','latitude':37.3,'longitude':126.8})
        self.assertEqual(result['place_name'],'카페')
        await service.set_location(7,10,RecordLocation())
        self.assertIsNone(repo.set_location.call_args.args[2]['latitude'])

    async def test_repository_write_also_scopes_user(self):
        from app.repositories.chatSessionRepository import ChatSessionRepository
        fake = SimpleNamespace(chatroom=SimpleNamespace(update_many=AsyncMock(return_value=1)))
        with patch('app.repositories.chatSessionRepository.db',fake):
            await ChatSessionRepository().set_location(7,10,RecordLocation().model_dump())
        self.assertEqual(fake.chatroom.update_many.call_args.kwargs['where'],{'user_id':7,'room_id':10})

if __name__ == '__main__': unittest.main()
