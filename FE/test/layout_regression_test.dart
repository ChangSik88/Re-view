import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/review/design.dart';
import 'package:frontend/review/review_state.dart';
import 'package:frontend/review/store_pages.dart';
import 'package:frontend/review/emotion_statistics_page.dart';

void main() {
  testWidgets(
      'Product actions remain visible and long cart scrolls on small phones',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final loader = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'));
    await loader.load();
    final state = ReviewState();
    await state.start(demo: true);
    for (var i = 0; i < 8; i++) {
      await state.addToCart(
          ShopItem(id: -200 - i, name: '긴 상품 이름 테스트 $i', price: 8900));
    }
    for (final width in [320.0, 393.0]) {
      tester.view.physicalSize = Size(width, 852);
      for (final entry in <String, Widget>{
        'product': ProductPage(item: state.products.first),
        'cart': const CartPage(),
        'statistics': const EmotionStatisticsPage(routine: Routine.morning),
      }.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(ChangeNotifierProvider.value(
            value: state,
            child: MaterialApp(
                theme: reviewTheme(),
                home: RepaintBoundary(key: key, child: entry.value))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${entry.key} at $width');
        if (entry.key == 'product') {
          final buy = find.text('구매하기');
          final before = tester.getCenter(buy);
          await tester.drag(
              find.byType(SingleChildScrollView).first, const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(tester.getCenter(buy), before);
          expect(before.dy, lessThan(852 - 32));
        }
        if (entry.key == 'cart') {
          await tester.scrollUntilVisible(find.text('구매하기'), 300,
              scrollable: find.byType(Scrollable).first);
          expect(find.text('구매하기').hitTestable(), findsOneWidget);
        }
        if (entry.key == 'statistics') {
          await tester.tap(find.text('1개월'));
          await tester.pumpAndSettle();
        }
        if (Platform.environment['CAPTURE_LAYOUT'] == '1' && width == 393) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/layout-review').create(recursive: true);
            await File('build/layout-review/${entry.key}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    }
  });
}
