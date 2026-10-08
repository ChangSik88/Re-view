import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'design.dart';
import 'review_state.dart';
import 'emotion_emoji.dart';

class EmotionStatisticsPage extends StatefulWidget {
  final Routine routine;
  const EmotionStatisticsPage({super.key, required this.routine});

  @override
  State<EmotionStatisticsPage> createState() => _EmotionStatisticsPageState();
}

class _EmotionStatisticsPageState extends State<EmotionStatisticsPage> {
  String period = '최근 4개';

  @override
  Widget build(BuildContext context) {
    final preview = context.watch<ReviewState>().preview;
    final subject = widget.routine == Routine.night ? '하루 기록' : '꿈';
    const values = [52, 25, 10, 8, 5, 0, 0, 0, 0];
    const labels = ['불안', '행복', '슬픔', '설렘', '편안', '기대', '분노', '피로', '놀람'];
    const colors = [0xFF6E63FF, 0xFF8F87FF, 0xFFA9A3FF, 0xFFBDB8FF, 0xFFCFCBFF];
    return ReviewPage(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            height: 40,
            child: Row(children: [
              IconButton(
                  tooltip: '뒤로가기',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24),
                  onPressed: () => Navigator.pop(context),
                  icon: const FigmaAsset('736-135/imgIconBack')),
              const Expanded(
                  child: Text('감정 전체보기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700))),
              const SizedBox(width: 24),
            ])),
        const SizedBox(height: 16),
        Text(
            period == '최근 4개'
                ? '최근 4개의 $subject에서 나타난 감정 비율이에요.'
                : '최근 $period 동안 기록한 $subject의 감정 비율이에요.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF555555))),
        const SizedBox(height: 16),
        Row(
            children: ['최근 4개', '1주', '1개월']
                .map((label) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Semantics(
                        selected: label == period,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => period = label),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                                color: label == period ? purple : Colors.white,
                                border: Border.all(
                                    color: label == period
                                        ? purple
                                        : const Color(0xFFC7C7C7)),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: label == period
                                        ? Colors.white
                                        : const Color(0xFF555555))),
                          ),
                        ),
                      ),
                    ))
                .toList()),
        const SizedBox(height: 16),
        if (!preview)
          const InfoBox('감정 비율은 아직 제공되지 않아요.\n통계 데이터가 연결되면 여기에서 확인할 수 있어요.')
        else ...[
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                        color: Color(0xFFECECFF), shape: BoxShape.circle),
                    child: const Center(
                        child: FigmaAsset('736-135/imgIconSpark'))),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('가장 자주 나타난 감정은 ‘불안’이에요.',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: purple))),
              ])),
          const SizedBox(height: 16),
          Paper(
              padding: const EdgeInsets.all(16),
              child: Column(
                  children: List.generate(labels.length, (i) {
                final active = values[i] > 0;
                return Padding(
                    padding: EdgeInsets.only(
                        top: 6, bottom: i == labels.length - 1 ? 6 : 8),
                    child: Row(children: [
                      Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? const Color(0xFFECECFF)
                                  : const Color(0xFFF4F4F8)),
                          child: Center(
                              child: Opacity(
                                  opacity: active ? 1 : .45,
                                  child: EmotionEmoji(
                                      emotion: labels[i], size: 20)))),
                      const SizedBox(width: 10),
                      SizedBox(
                          width: 34,
                          child: Text(labels[i],
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? Colors.black
                                      : const Color(0xFFA8A8B5)))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                  value: values[i] / 100,
                                  minHeight: 10,
                                  backgroundColor: const Color(0xFFF0EEFF),
                                  color: Color(colors[i.clamp(0, 4)])))),
                      const SizedBox(width: 10),
                      SizedBox(
                          width: 38,
                          child: Text('${values[i]}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? purple
                                      : const Color(0xFFA8A8B5)))),
                    ]));
              }))),
          const SizedBox(height: 16),
          const Text('기록 1건당 최대 3개 감정을 반영한 평균 비율이에요.\n디자인 확인용 예시 통계입니다.',
              style: TextStyle(fontSize: 11, color: Color(0xFF7A7A7A))),
        ],
      ],
    ));
  }
}
