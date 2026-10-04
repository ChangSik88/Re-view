import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/review/review_state.dart';
import 'package:frontend/review/design.dart';
import 'package:frontend/review/diary_pages.dart';
import 'package:frontend/review/chat_page.dart';
import 'package:frontend/review/store_pages.dart';
import 'package:frontend/review/settings_page.dart';
import 'package:frontend/review/emotion_statistics_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Night emotion statistics opens and returns to same home',
      (tester) async {
    final state = ReviewState();
    await state.start(demo: true);
    await mount(tester, state, const DiaryHomePage(routine: Routine.night));
    await tester.tap(find.text('전체보기'));
    await tester.pumpAndSettle();
    expect(find.byType(EmotionStatisticsPage), findsOneWidget);
    expect(find.text('최근 4개의 하루 기록에서 나타난 감정 비율이에요.'), findsOneWidget);
    expect(find.text('52%'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.text('하루 감정 통계'), findsOneWidget);
    expect(find.text('나이트루틴'), findsOneWidget);
  });
  testWidgets('Real statistics never display prototype percentages',
      (tester) async {
    await mount(tester, ReviewState(),
        const EmotionStatisticsPage(routine: Routine.night));
    expect(find.text('52%'), findsNothing);
    expect(find.textContaining('감정 비율은 아직 제공되지'), findsOneWidget);
  });
  test('Previous day lookup matches exact date and NIGHT routine', () async {
    final state = ReviewState();
    await state.start(demo: true);
    final morning13 = state.records.firstWhere((r) => r.id == -13);
    final morning6 = state.records.firstWhere((r) => r.id == -6);
    expect(state.previousNight(morning13)?.id, -112);
    expect(state.previousNight(morning6), isNull);
    expect(
        state
            .forRoutine(Routine.night)
            .every((r) => r.routine == Routine.night),
        isTrue);
  });
  test('Cart removal, clear and selected totals survive persistence', () async {
    final state = ReviewState()..account = 'test';
    final a = ShopItem(id: 1, name: 'A', price: 8900);
    final b = ShopItem(id: 2, name: 'B', price: 12900);
    await state.addToCart(a);
    await state.addToCart(a);
    await state.addToCart(b);
    expect(state.total, 30700);
    state.cart.last.selected = false;
    await state.saveCart();
    expect(state.total, 17800);
    await state.removeFromCart(1);
    expect(state.cart.length, 1);
    expect(state.total, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('review_cart_test'), contains('B'));
    expect(prefs.getString('review_cart_test'), isNot(contains('"A"')));
    await state.clearCart();
    expect(state.total, 0);
    expect(prefs.getString('review_cart_test'), '[]');
  });
  testWidgets(
      'Night bookmark calendar toggles and routine dropdown keep routine',
      (tester) async {
    final state = ReviewState();
    await state.start(demo: true);
    await mount(tester, state, const DiaryHomePage(routine: Routine.night));
    await tester.tap(find.text('북마크'));
    await tester.pumpAndSettle();
    expect(find.text('전체 4'), findsOneWidget);
    await tester.tap(find.text('캘린더'));
    await tester.pumpAndSettle();
    expect(find.text('하루 감정 통계'), findsOneWidget);
    await tester.tap(find.text('나이트루틴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모닝루틴'));
    await tester.pumpAndSettle();
    expect(find.text('내 꿈나라'), findsOneWidget);
    expect(find.text('꿈 감정 통계'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Character other dialog closes only overlay and returns to chat',
      (tester) async {
    final state = ReviewState();
    await state.start(demo: true);
    await mount(tester, state, const ReviewChatPage(routine: Routine.morning));
    await tester.tap(find.text('등장인물'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기타'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '모르는 학생');
    await tester.tap(find.text('수정 완료'));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterDialog), findsNothing);
    expect(find.byType(ReviewChatPage), findsOneWidget);
    expect(find.textContaining('모르는 학생'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Analysis X always goes to same routine home', (tester) async {
    final state = ReviewState();
    await state.start(demo: true);
    final record = state.forRoutine(Routine.night).first;
    await mount(tester, state, AnalysisPage(record: record));
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryHomePage), findsOneWidget);
    expect(find.text('내 일기장'), findsOneWidget);
  });
  testWidgets('Bookmark changes update list immediately', (tester) async {
    final state = ReviewState();
    await state.start(demo: true);
    final record = state.forRoutine(Routine.morning).first;
    await state.toggleMarked(record);
    await mount(tester, state, const DiaryHomePage());
    await tester.tap(find.text('북마크'));
    await tester.pumpAndSettle();
    expect(find.text('전체 4'), findsOneWidget);
    expect(find.text(record.title), findsNothing);
  });
  testWidgets('Cart item X and clear remove visible products', (tester) async {
    final state = ReviewState();
    await state.start(demo: true);
    await state.addToCart(state.products[0]);
    await state.addToCart(state.products[2]);
    await mount(tester, state, const CartPage());
    await tester.tap(find.byTooltip('${state.products[0].name} 삭제'));
    await tester.pumpAndSettle();
    expect(find.text(state.products[0].name), findsNothing);
    await tester.tap(find.text('전체 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('장바구니가 비어 있어요.'), findsOneWidget);
  });
  testWidgets('All pages fit a 360px phone and respect camera inset',
      (tester) async {
    final state = ReviewState();
    await state.start(demo: true);
    final record = state.records.first;
    for (final page in <Widget>[
      const HomePage(),
      const DiaryHomePage(),
      const DiaryHomePage(routine: Routine.night),
      const CalendarPage(),
      const SearchPage(routine: Routine.night),
      AnalysisPage(record: record),
      const ShopPage(),
      ProductPage(item: state.products.first),
      const SettingsPage()
    ]) {
      await mount(tester, state, page);
      expect(tester.takeException(), isNull,
          reason: '${page.runtimeType} must not overflow');
      final header = find.byType(PageHeader);
      if (header.evaluate().isNotEmpty)
        expect(tester.getTopLeft(header.first).dy, greaterThanOrEqualTo(32));
    }
  });
}

Future<void> mount(WidgetTester tester, ReviewState state, Widget page) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
          theme: reviewTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 32, bottom: 20)),
              child: child!),
          home: page)));
  await tester.pumpAndSettle();
}
