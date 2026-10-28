import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/review/chat_page.dart';
import 'package:frontend/review/diary_pages.dart';
import 'package:frontend/review/review_state.dart';

void main() {
  testWidgets('finish night conversation saves and opens daily report',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = ReviewState();
    await state.start(demo: true);
    final count = state.records.length;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: ReviewChatPage(routine: Routine.night))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대화 마무리'));
    await tester.pumpAndSettle();
    expect(state.records.length, count);
    expect(find.byType(ReviewChatPage), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(ReviewChatPage))).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '오늘 친구와 공원에서 산책했어');
    await tester.tap(find.byTooltip('메시지 보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대화 마무리'));
    await tester.pumpAndSettle();
    expect(state.records.length, count + 1);
    expect(state.records.last.content, contains('오늘 친구와 공원에서 산책했어'));
    expect(state.records.last.content, contains('하루 돌아보기'));
    expect(find.byType(AnalysisPage), findsOneWidget);
    expect(find.text('하루 리포트'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
