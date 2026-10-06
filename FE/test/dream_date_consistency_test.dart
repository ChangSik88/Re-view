import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/review/design.dart';
import 'package:frontend/review/diary_pages.dart';
import 'package:frontend/review/emotion_statistics_page.dart';
import 'package:frontend/review/review_state.dart';

void main() {
  testWidgets(
      'Every dream date opens statistics in preview and authenticated mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = ReviewState();
    await state.start(demo: true);
    for (final preview in [true, false]) {
      state.preview = preview;
      for (final record in state.forRoutine(Routine.morning)) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(ChangeNotifierProvider.value(
            value: state,
            child: MaterialApp(
                theme: reviewTheme(), home: DiaryHomePage(selected: record))));
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.text('내 꿈나라')).style!.fontWeight,
            FontWeight.w600);
        final link = find.descendant(
            of: find.byType(EmotionCard), matching: find.text('전체보기'));
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byType(EmotionStatisticsPage), findsOneWidget);
        await tester.tap(find.text('1주'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1개월'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Short and multiline summaries keep the same button position',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    double? buttonY;
    for (final title in ['짧은 꿈', '아주 긴 꿈 제목이 여러 줄로 이어져도 같은 영역 안에 표시되는 꿈 기록']) {
      final record = DiaryRecord(
          id: 1,
          date: DateTime(2026, 4, 6),
          routine: Routine.morning,
          title: title,
          content: '첫 문장\n\n다음 문장입니다.');
      await tester.pumpWidget(MaterialApp(
          theme: reviewTheme(),
          home: Scaffold(
              body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SummaryCard(record: record)))));
      await tester.pumpAndSettle();
      final y = tester.getTopLeft(find.text('AI 해석보기  ›')).dy;
      buttonY ??= y;
      expect(y, closeTo(buttonY!, 0.5));
      expect(tester.takeException(), isNull);
    }
  });
}
