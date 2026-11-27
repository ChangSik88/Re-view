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
import 'package:frontend/review/emotion_statistics_page.dart';

void main() {
  testWidgets('Statistics page lays out on small phones', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final loader = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'));
    await loader.load();
    final state = ReviewState();
    await state.start(demo: true);
    for (final width in [320.0, 393.0]) {
      tester.view.physicalSize = Size(width, 852);
      for (final entry in <String, Widget>{
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
