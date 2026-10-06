import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/review/chat_page.dart';
import 'package:frontend/review/design.dart';
import 'package:frontend/review/review_state.dart';
import 'package:frontend/services/chat_service.dart';

class LumiService extends ChatService {
  int sessions = 0;
  final sent = <String>[];
  Completer<Map<String, dynamic>> response = Completer();
  @override
  Future<int> createSession(String routineType, String? userId) async {
    sessions++;
    return 42;
  }

  @override
  Future<Map<String, dynamic>> sendMessage(int id, String message) {
    sent.add(message);
    return response.future;
  }
}

void main() {
  testWidgets(
      'Lumi reveals real service reply, extracts details and reuses session',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = LumiService();
    final state = ReviewState()..account = 'tester';
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
            theme: reviewTheme(),
            home: ReviewChatPage(routine: Routine.night, service: service))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '학교에서 친구와 놀았어');
    await tester.tap(find.byTooltip('메시지 보내기'));
    await tester.pump();
    expect(service.sent, ['학교에서 친구와 놀았어']);
    expect(find.text('루미가 답장을 생각하고 있어요…'), findsOneWidget);
    const reply = '친구와 즐거운 시간을 보내셨군요! 어떤 순간이 가장 기억에 남나요?';
    service.response.complete({
      'analysis': {
        'ai_reply': reply,
        'suggested_feelings': ['행복'],
        'story_details': {
          'place': '학교',
          'characters': ['친구']
        }
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    expect(find.text(reply), findsNothing);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(find.text(reply), findsOneWidget);
    expect(find.text('학교'), findsOneWidget);
    await tester.ensureVisible(find.text('장소'));
    await tester.tap(find.text('장소'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '공원');
    await tester.tap(find.text('수정 완료'));
    await tester.pumpAndSettle();
    service.response = Completer();
    await tester.enterText(find.byType(TextField), '같이 웃던 순간');
    await tester.tap(find.byTooltip('메시지 보내기'));
    await tester.pump();
    expect(service.sessions, 1);
    service.response.complete({
      'analysis': {
        'ai_reply': '좋아요!',
        'story_details': {'place': '학교'}
      }
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(find.text('공원'), findsOneWidget);
    service.response = Completer();
    await tester.enterText(find.byType(TextField), '다음 이야기');
    await tester.tap(find.byTooltip('메시지 보내기'));
    await tester.pump();
    service.response.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('다음 이야기'), findsWidgets);
    expect(find.textContaining('응답을 받지 못했어요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
