import 'package:flutter/material.dart';
import 'design.dart';
import 'review_state.dart';

const _seriesColors = [Color(0xFF8F7BFF), Color(0xFFFF8F8F), Color(0xFF3CC8E0)];

/// 나이트루틴 'AI 감정 인사이트' 탭: 어제→오늘 감정 태그, 감정 변화 차트.
/// 감정 데이터는 기록의 태그(사용자가 고른 감정)를 그대로 쓴다.
class NightInsight extends StatelessWidget {
  final DiaryRecord record;
  final List<DiaryRecord> records;
  const NightInsight({super.key, required this.record, required this.records});

  List<DiaryRecord> _nightOn(DateTime day) => records
      .where((r) => r.routine == Routine.night && sameDate(r.date, day))
      .toList();

  @override
  Widget build(BuildContext context) {
    final base = DateTime(record.date.year, record.date.month, record.date.day);
    final days = List.generate(4, (i) => base.subtract(Duration(days: 3 - i)));
    final tagsByDay = [
      for (final d in days) _nightOn(d).expand((r) => r.tags).toList()
    ];
    final previous = tagsByDay[2];
    final today = record.tags;

    final totals = <String, int>{};
    for (final tags in tagsByDay) {
      for (final t in tags) {
        totals[t] = (totals[t] ?? 0) + 1;
      }
    }
    final top = (totals.keys.toList()
          ..sort((a, b) => totals[b]!.compareTo(totals[a]!)))
        .take(3)
        .toList();
    final carried = today.where(previous.contains).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Side(Icons.dark_mode_outlined, '어제', previous),
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(Icons.arrow_forward, color: purple, size: 20)),
            _Side(Icons.wb_sunny_outlined, '오늘', today),
          ]),
      gap,
      const Divider(),
      gap,
      if (previous.isEmpty)
        const _Banner(Icons.auto_awesome, '전날 하루 기록이 없어요.',
            '하루를 꾸준히 기록하면 감정의 흐름을 볼 수 있어요.')
      else if (carried.isEmpty)
        const _Banner(Icons.auto_awesome, '어제와는 다른 감정으로 하루를 보냈어요.', null)
      else
        _Banner(Icons.auto_awesome, '어제 하루의 ‘${carried.first}’이 오늘도 이어졌어요.',
            today.length > carried.length ? '새로운 감정도 함께 나타났어요.' : null),
      const SizedBox(height: 20),
      const Text('주요 감정 변화',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      gap,
      if (top.isEmpty)
        const InfoBox('아직 기록된 감정이 없어요.')
      else ...[
        SizedBox(
            height: 145,
            child: Row(children: [
              Expanded(
                  child: CustomPaint(
                      size: Size.infinite,
                      painter: _EmotionChart(days: days, series: [
                        for (final e in top)
                          [
                            for (final tags in tagsByDay)
                              tags.where((t) => t == e).length
                          ]
                      ]))),
              SizedBox(
                  width: 56,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < top.length; i++)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                            color: _seriesColors[i],
                                            width: 2))),
                                const SizedBox(width: 6),
                                Flexible(
                                    child: Text(top[i],
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11)))
                              ]))
                      ]))
            ])),
        gap,
        _Banner(
            Icons.favorite_border, '최근 가장 자주 기록된 감정은 ‘${top.first}’이에요.', null),
      ],
      gap,
      const Divider(),
      gap,
    ]);
  }
}

class _Side extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> tags;
  const _Side(this.icon, this.label, this.tags);
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 110,
      child: Column(children: [
        Icon(icon, color: purple, size: 34),
        Text(label, style: const TextStyle(fontSize: 11, color: muted)),
        gap,
        Tags(tags.take(3).toList())
      ]));
}

class _EmotionChart extends CustomPainter {
  final List<DateTime> days;
  final List<List<int>> series;
  _EmotionChart({required this.days, required this.series});

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 18.0, pad = 12.0;
    final h = size.height - labelH;
    final peak = series.expand((s) => s).fold<int>(1, (a, b) => a > b ? a : b);
    final step = (size.width - pad * 2) / (days.length - 1);
    double x(int i) => pad + step * i;
    double y(int v) => h - 10 - (h - 20) * v / peak;

    final grid = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (var i = 0; i < days.length; i++) {
      for (var yy = 0.0; yy < h; yy += 6) {
        canvas.drawLine(Offset(x(i), yy), Offset(x(i), yy + 3), grid);
      }
      final tp = TextPainter(
          text: TextSpan(
              text: '${days[i].month}/${days[i].day}',
              style: const TextStyle(fontSize: 10, color: muted)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x(i) - tp.width / 2, h + 4));
    }
    for (var s = 0; s < series.length; s++) {
      final color = _seriesColors[s];
      final line = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < days.length; i++) {
        final p = Offset(x(i), y(series[s][i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, line);
      for (var i = 0; i < days.length; i++) {
        final p = Offset(x(i), y(series[s][i]));
        canvas.drawCircle(p, 4, Paint()..color = Colors.white);
        canvas.drawCircle(p, 4, line..strokeWidth = 1.6);
      }
    }
  }

  @override
  bool shouldRepaint(_EmotionChart old) => true;
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  const _Banner(this.icon, this.title, this.sub);
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: lavender, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: purple, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: purple)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: const TextStyle(fontSize: 10, height: 1.5))
          ]
        ]))
      ]));
}

/// 나이트 일기 본문을 빈 줄 기준 블록(소제목 + 내용)으로 나눠 깔끔하게 보여준다.
class NightReport extends StatelessWidget {
  final String content;
  const NightReport(this.content, {super.key});
  @override
  Widget build(BuildContext context) {
    final blocks = content
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    if (blocks.isEmpty) {
      return const Text('아직 작성된 본문이 없어요.',
          style: TextStyle(fontSize: 12, height: 1.8));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final b in blocks)
        Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (b.contains('\n')) ...[
                Text(b.split('\n').first.trim(),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(b.split('\n').skip(1).join('\n').trim(),
                    style: const TextStyle(
                        fontSize: 12, height: 1.8, color: Color(0xFF444444)))
              ] else
                Text(b, style: const TextStyle(fontSize: 12, height: 1.8))
            ]))
    ]);
  }
}
