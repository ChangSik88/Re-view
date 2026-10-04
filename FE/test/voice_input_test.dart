import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/review/design.dart';
import 'package:frontend/review/voice_composer.dart';
import 'package:frontend/services/voice_input_service.dart';

class FakeRecognizer implements VoiceRecognizer {
  late void Function(String) words, error;
  late void Function() done;
  int starts = 0, cancels = 0;
  bool deny = false;
  @override
  Future<void> start(Object owner,
      {required void Function(String) onWords,
      required void Function() onDone,
      required void Function(String) onError}) async {
    starts++;
    words = onWords;
    done = onDone;
    error = onError;
    if (deny) onError('마이크 권한이 필요해요.');
  }

  @override
  Future<void> stop(Object owner) async {
    done();
  }

  @override
  Future<void> cancel(Object owner) async {
    cancels++;
  }
}

void main() {
  testWidgets(
      'Microphone transcribes partial results without duplicating or auto sending',
      (tester) async {
    final engine = FakeRecognizer();
    final input = TextEditingController(text: '오늘');
    var sent = 0;
    await tester.pumpWidget(MaterialApp(
        theme: reviewTheme(),
        home: Scaffold(
            body: VoiceComposer(
                controller: input, recognizer: engine, onSend: () => sent++))));
    await tester.tap(find.byTooltip('음성으로 입력'));
    await tester.pump();
    engine.words('학교');
    await tester.pump();
    expect(input.text, '오늘 학교');
    engine.words('학교에 갔어요');
    await tester.pump();
    expect(input.text, '오늘 학교에 갔어요');
    expect(sent, 0);
    final send = tester.widget<IconButton>(find
        .byWidgetPredicate((w) => w is IconButton && w.tooltip == '메시지 보내기'));
    expect(send.onPressed, isNull);
    await tester.tap(find.byTooltip('음성 입력 종료'));
    await tester.pump();
    await tester.tap(find.byTooltip('메시지 보내기'));
    expect(sent, 1);
    await tester.pumpWidget(const SizedBox());
    input.dispose();
  });
  testWidgets('Permission denial preserves draft and permits retry',
      (tester) async {
    final engine = FakeRecognizer()..deny = true;
    final input = TextEditingController(text: '내 꿈');
    await tester.pumpWidget(MaterialApp(
        theme: reviewTheme(),
        home: Scaffold(
            body: VoiceComposer(
                controller: input, recognizer: engine, onSend: () {}))));
    await tester.tap(find.byTooltip('음성으로 입력'));
    await tester.pumpAndSettle();
    expect(find.text('마이크 권한이 필요해요.'), findsOneWidget);
    expect(input.text, '내 꿈');
    engine.deny = false;
    await tester.tap(find.byTooltip('음성으로 입력'));
    await tester.pump();
    expect(engine.starts, 2);
    expect(find.byTooltip('음성 입력 종료'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    input.dispose();
  });
  testWidgets('Leaving chat cancels microphone and ignores late recognition',
      (tester) async {
    final engine = FakeRecognizer();
    final input = TextEditingController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VoiceComposer(
                controller: input, recognizer: engine, onSend: () {}))));
    await tester.tap(find.byTooltip('음성으로 입력'));
    await tester.pump();
    engine.words('유지할 내용');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(engine.cancels, 1);
    engine.words('늦게 도착한 내용');
    engine.done();
    await tester.pump();
    expect(input.text, '유지할 내용');
    expect(tester.takeException(), isNull);
    input.dispose();
  });
}
