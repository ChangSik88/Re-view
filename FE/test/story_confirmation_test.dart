import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/review/chat_page.dart';
import 'package:frontend/review/design.dart';
import 'package:frontend/review/diary_pages.dart';
import 'package:frontend/review/review_state.dart';
import 'package:frontend/review/story_details.dart';
import 'package:frontend/services/chat_service.dart';

class RecordingChatService extends ChatService {
  final events = <String>[];
  bool fail = false;
  @override
  Future<Map<String, dynamic>> sendMessage(int id, String message) async {
    events.add(message);
    if (fail) throw Exception('network');
    return {};
  }

  @override
  Future<void> generateDiary(int id, List<String> feelings) async {
    events.add('generate:${feelings.join(',')}');
  }
}

void main() {
  test(
      'Confirmed fields reach history before generation; failure prevents generation',
      () async {
    const details = StoryDetails(
        place: '학교',
        characters: '친구',
        emotions: '설렘',
        life: '새 학기',
        memo: '비가 옴');
    final service = RecordingChatService();
    await service.confirmAndGenerate(1, details.confirmation, ['설렘']);
    for (final value in [
      '장소: 학교',
      '등장인물: 친구',
      '감정: 설렘',
      '생활: 새 학기',
      '기타 메모: 비가 옴'
    ]) {
      expect(service.events.first, contains(value));
    }
    expect(service.events.last, 'generate:설렘');
    service.events.clear();
    service.fail = true;
    await expectLater(service.confirmAndGenerate(1, details.confirmation, []),
        throwsException);
    expect(service.events.length, 1);
  });
  testWidgets(
      'Edit all fields and confirm retains entered information in preview result',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = ReviewState();
    await state.start(demo: true);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
            theme: reviewTheme(),
            home: const ReviewChatPage(routine: Routine.morning))));
    await tester.pumpAndSettle();
    for (final entry
        in {'장소': '학교', '감정': '설렘', '생활': '새 학기', '기타 메모': '비가 옴'}.entries) {
      await tester.ensureVisible(find.text(entry.key));
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, entry.value);
      await tester.tap(find.text('수정 완료'));
      await tester.pumpAndSettle();
    }
    expect(find.text('등장인물'), findsOneWidget);
    await tester.ensureVisible(find.text('정보가 맞아요'));
    await tester.tap(find.text('정보가 맞아요'));
    await tester.pumpAndSettle();
    expect(find.byType(AnalysisPage), findsOneWidget);
    final result = state.records.last;
    for (final value in ['학교', '친구', '설렘', '새 학기', '비가 옴']) {
      expect(result.content, contains(value));
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('Emotion graphic is centered in the full card width',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = ReviewState();
    await state.start(demo: true);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
            theme: reviewTheme(),
            home: const Scaffold(
                body: Center(
                    child: SizedBox(
                        width: 380,
                        child: EmotionCard(routine: Routine.morning)))))));
    await tester.pumpAndSettle();
    final graphic = find
        .descendant(of: find.byType(FittedBox), matching: find.byType(Row))
        .first;
    expect(tester.getCenter(graphic).dx,
        closeTo(tester.getCenter(find.byType(EmotionCard)).dx, .1));
  });
}
