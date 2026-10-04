// Run with: flutter test --no-pub tool/render_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  testWidgets('Export preview screens for visual inspection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fonts = FontLoader('Pretendard');
    for (final path in [
      'assets/fonts/Pretendard-Regular.otf',
      'assets/fonts/Pretendard-SemiBold.otf',
      'assets/fonts/Pretendard-Bold.ttf'
    ]) {
      fonts.addFont(rootBundle.load(path));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = ReviewState();
    await state.start(demo: true);
    await state.loadProducts();
    await state.addToCart(state.products.first);
    final target = Directory('build/design-preview')
      ..createSync(recursive: true);
    final record = state.records.firstWhere((r) => r.id == -13);
    final screens = <String, Widget>{
      'home': const HomePage(),
      'morning': DiaryHomePage(selected: record),
      'night': const DiaryHomePage(routine: Routine.night),
      'emotion-statistics': const EmotionStatisticsPage(routine: Routine.night),
      'analysis': AnalysisPage(record: record),
      'analysis-full': AnalysisPage(record: record),
      'analysis-insights': AnalysisPage(record: record),
      'bookmarks': DiaryHomePage(selected: record),
      'calendar': const CalendarPage(),
      'search': const SearchPage(routine: Routine.morning),
      'chat': const ReviewChatPage(routine: Routine.morning),
      'store': const ShopPage(),
      'product': ProductPage(item: state.products.first),
      'cart': const CartPage(),
      'settings': const SettingsPage(),
    };
    for (final entry in screens.entries) {
      await tester.pumpWidget(const SizedBox.shrink());
      final key = GlobalKey();
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
              theme: reviewTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 32, bottom: 20)),
                  child: child!),
              home: RepaintBoundary(key: key, child: entry.value))));
      await tester.pumpAndSettle();
      final tabLabel = switch (entry.key) {
        'analysis-full' => '전문 보기',
        'analysis-insights' => 'AI 감정 인사이트',
        'bookmarks' => '북마크',
        _ => null,
      };
      if (tabLabel != null) {
        await tester.tap(find.text(tabLabel));
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() async {
        for (final source in [
          previewDreamImage,
          'assets/figma/188107ea-a224-4fe1-aa06-708975b55370.png',
          'assets/figma/b73dc5d5-779d-44bf-810e-681b0b65df6f.png'
        ]) {
          await precacheImage(AssetImage(source), key.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${target.path}/${entry.key}.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    debugDisableShadows = true;
  });
}
