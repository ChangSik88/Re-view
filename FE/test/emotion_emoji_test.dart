import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/review/emotion_emoji.dart';

void main() {
  test('All nine emotions differ and known aliases match', () {
    const labels = ['행복', '불안', '슬픔', '설렘', '편안', '기대', '분노', '피로', '놀람'];
    expect(labels.map(emotionEmoji).toSet().length, 9);
    expect(emotionEmoji(' #피곤 '), emotionEmoji('피로'));
    expect(emotionEmoji('평안'), emotionEmoji('편안'));
    expect(recordedEmotion(['입학식', '불안', '설렘']), '불안');
    expect(recordedEmotion(['학교', '친구']), isNull);
    expect(recordedEmotion([]), isNull);
  });

  testWidgets(
      'Changing a selected emotion changes the face; missing data is neutral',
      (tester) async {
    for (final emotion in ['행복', '불안', '피로', null]) {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: EmotionEmoji(emotion: emotion))));
      if (emotion == null) {
        expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
        expect(find.text('😊'), findsNothing);
      } else {
        expect(find.text(emotionEmoji(emotion)!), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });
}
