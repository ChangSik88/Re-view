import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/review/location_pages.dart';
import 'package:frontend/services/session_service.dart';
import 'package:frontend/review/diary_pages.dart';
import 'package:frontend/review/design.dart';
import 'package:frontend/review/review_state.dart';

DiaryRecord record(int id,
        {Routine routine = Routine.night,
        String? place = '카페',
        double? lat = 37.3}) =>
    DiaryRecord(
        id: id,
        date: DateTime(2026, 10, id),
        routine: routine,
        title: '하루 $id',
        content: '하루 이야기',
        placeName: place,
        latitude: lat,
        longitude: lat == null ? null : 126.8);
Widget app(ReviewState state, Widget home) => ChangeNotifierProvider.value(
    value: state, child: MaterialApp(theme: reviewTheme(), home: home));

class FailingSessions extends SessionService {
  @override
  Future<void> setLocation(int id, Map<String, dynamic> location) async =>
      throw Exception('offline');
}

void main() {
  test('failed server save leaves previous place unchanged', () async {
    final r = record(1);
    final state = ReviewState(sessions: FailingSessions())..records = [r];
    await expectLater(state.saveLocation(r, '공원', 38, 128), throwsException);
    expect(r.placeName, '카페');
    expect(r.latitude, 37.3);
  });
  test('remove and reassign places updates map immediately', () async {
    final r = record(1);
    final state = ReviewState()
      ..preview = true
      ..records = [r];
    await state.saveLocation(r, null, null, null);
    expect(recordPlaces(state.records), isEmpty);
    await state.saveLocation(r, '공원', 38, 128);
    expect(recordPlaces(state.records).single.name, '공원');
  });
  testWidgets('capture location panel with actual app typography',
      (tester) async {
    if (Platform.environment['CAPTURE_LAYOUT'] != '1') return;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf')))
        .load();
    final state = ReviewState()
      ..preview = true
      ..records = [record(1), record(2)];
    final key = GlobalKey();
    await tester.pumpWidget(app(
        state,
        RepaintBoundary(
            key: key, child: const LocationMapPage(loadTiles: false))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카페'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/layout-review').create(recursive: true);
      await File('build/layout-review/location.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
  test('groups repeated visits, excludes dream and unlocated records', () {
    final groups = recordPlaces([
      record(1),
      record(2),
      record(3, routine: Routine.morning),
      record(4, place: null, lat: null),
      record(5, lat: 38)
    ]);
    expect(groups.length, 2);
    expect(groups.last.records.map((r) => r.id), [2, 1]);
  });
  test('server location survives record deserialization', () {
    final r = DiaryRecord.fromJson({
      'room_id': 1,
      'routine_type': 'Night',
      'place_name': '카페',
      'latitude': 37.3,
      'longitude': 126.8
    });
    expect(r.hasLocation, true);
    expect(r.placeName, '카페');
  });
  for (final width in [320.0, 393.0]) {
    testWidgets('map selection opens matching report at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = ReviewState()
        ..preview = true
        ..records = [record(1), record(2)];
      await tester
          .pumpWidget(app(state, const LocationMapPage(loadTiles: false)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('카페'));
      await tester.pumpAndSettle();
      expect(find.text('기록 2개 · 나이트루틴'), findsOneWidget);
      await tester.ensureVisible(find.text('리포트 보기'));
      await tester.tap(find.text('리포트 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(AnalysisPage), findsOneWidget);
      expect(find.text('하루 2'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('permission failure still allows manual location save',
      (tester) async {
    final r = record(1, place: null, lat: null);
    final state = ReviewState()
      ..preview = true
      ..records = [r];
    await tester.pumpWidget(app(
        state,
        LocationEditorPage(
            record: r,
            loadTiles: false,
            locate: () async => throw Exception('denied'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('현재 위치로 이동'));
    await tester.pumpAndSettle();
    expect(find.textContaining('직접 눌러'), findsWidgets);
    final map = tester.widget<RecordMap>(find.byType(RecordMap));
    map.onPick!(const LatLng(37.4, 126.9));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  공원  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('이 장소 저장'));
    await tester.tap(find.text('이 장소 저장'));
    await tester.pumpAndSettle();
    expect(r.placeName, '공원');
    expect(r.latitude, 37.4);
    expect(r.longitude, 126.9);
  });
  testWidgets('blank location is not silently saved', (tester) async {
    final r = record(1, place: null, lat: null);
    final state = ReviewState()
      ..preview = true
      ..records = [r];
    await tester.pumpWidget(
        app(state, LocationEditorPage(record: r, loadTiles: false)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('이 장소 저장'));
    await tester.tap(find.text('이 장소 저장'));
    await tester.pumpAndSettle();
    expect(r.hasLocation, false);
    expect(find.textContaining('장소 이름을 입력'), findsOneWidget);
  });
}
