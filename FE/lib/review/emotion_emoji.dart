import 'package:flutter/material.dart';

/// Match recorded labels only; do not infer feelings from a diary's prose.
String? emotionEmoji(String label) {
  final key = label.trim().replaceFirst(RegExp(r'^#'), '').trim();
  return switch (key) {
    '행복' || '기쁨' || '즐거움' => '😊',
    '불안' || '걱정' || '긴장' => '😟',
    '슬픔' || '우울' || '외로움' => '😢',
    '설렘' || '사랑' => '🥰',
    '편안' || '평안' || '평온' || '안정' => '😌',
    '기대' || '희망' => '🤩',
    '분노' || '화남' || '짜증' => '😠',
    '피로' || '피곤' || '지침' => '😴',
    '놀람' || '당황' => '😮',
    _ => null,
  };
}

/// Tags are not ranked scores: use the first recognized emotion in API order.
String? recordedEmotion(Iterable<String> tags) {
  for (final tag in tags) {
    if (emotionEmoji(tag) != null) return tag;
  }
  return null;
}

class EmotionEmoji extends StatelessWidget {
  final String? emotion;
  final double size;
  const EmotionEmoji({super.key, this.emotion, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final emoji = emotion == null ? null : emotionEmoji(emotion!);
    return Semantics(
      label: emoji == null ? '감정 정보 없음' : '감정: $emotion',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size + 4,
          height: size + 4,
          child: Center(
              child: emoji == null
                  ? Icon(Icons.remove_circle_outline,
                      size: size, color: const Color(0xFFB5B1CC))
                  : Text(emoji,
                      style: TextStyle(
                          fontSize: size,
                          height: 1,
                          fontFamily: 'sans-serif',
                          fontWeight: FontWeight.normal))),
        ),
      ),
    );
  }
}
