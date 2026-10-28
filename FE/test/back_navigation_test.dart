import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/review/back_navigation_guard.dart';

void main() {
  Widget page(String label, {bool home = false}) => BackNavigationGuard(
        isHome: home,
        child: Scaffold(body: Text(label)),
      );

  testWidgets('root tab returns home; home requires explicit exit',
      (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
      home: page('store'),
      routes: {'/home': (_) => page('home', home: true)},
    ));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(calls, isNot(contains('SystemNavigator.pop')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('앱을 종료할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('SystemNavigator.pop')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('종료'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'SystemNavigator.pop'), hasLength(1));
  });

  testWidgets('detail back returns to previous route without exit dialog',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: page('home', home: true)));
    navigator.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => page('detail')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('detail'), findsNothing);
    expect(find.text('앱을 종료할까요?'), findsNothing);
  });
}
