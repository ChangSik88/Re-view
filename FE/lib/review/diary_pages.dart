import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/report_service.dart';
import 'design.dart';
import 'review_state.dart';
import 'chat_page.dart';
import 'emotion_statistics_page.dart';

void openChat(BuildContext context, Routine routine, [DiaryRecord? record]) =>
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ReviewChatPage(routine: routine, record: record)));
void openDiaryHome(BuildContext context, DiaryRecord record) => Navigator.push(
    context,
    MaterialPageRoute(
        builder: (_) =>
            DiaryHomePage(routine: record.routine, selected: record)));
void openAnalysis(BuildContext context, DiaryRecord record) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => AnalysisPage(record: record)));

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReviewState>();
    final records = state.forRoutine(Routine.morning);
    final anchor = records.isEmpty ? DateTime.now() : records.last.date;
    final first =
        DateTime(anchor.year, anchor.month, anchor.day - anchor.weekday + 1);
    void calendar() => Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CalendarPage()));
    void shop() => Navigator.pushNamed(context, '/store');
    return ReviewPage(
        tab: 0,
        horizontalPadding: 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PageHeader(leading: false, actions: [
            IconButton(
                tooltip: '알림',
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
                icon: const FIcon('bell'))
          ]),
          const SizedBox(height: 20),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '오늘 어떤 '),
                            TextSpan(
                                text: '꿈', style: TextStyle(color: purple)),
                            TextSpan(text: '을\n꾸셨나요?')
                          ]),
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              height: 1.2)),
                      SizedBox(height: 10),
                      Text('AI가 당신의 꿈을 기록하고,\n의미를 분석해드려요.',
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              color: Color(0xFF585858))),
                    ])),
                LumiArt(width: 128, height: 108),
              ])),
          const SizedBox(height: 22),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(children: [
                Expanded(
                    child: PrimaryButton(state.guest ? '로그인' : '꿈 기록하기',
                        height: 42,
                        radius: 10,
                        onPressed: () => state.guest
                            ? Navigator.pushNamed(context, '/login')
                            : openChat(context, Routine.morning))),
                const SizedBox(width: 12),
                Expanded(
                    child: PrimaryButton(state.guest ? '회원가입' : '하루 기록하기',
                        height: 42,
                        radius: 10,
                        outlined: true,
                        onPressed: () => state.guest
                            ? Navigator.pushNamed(context, '/signup')
                            : openChat(context, Routine.night))),
              ])),
          const SizedBox(height: 20),
          if (state.loading) const LinearProgressIndicator(minHeight: 2),
          if (state.error != null) ...[
            InfoBox(state.error!, retry: state.refresh),
            gap
          ],
          Paper(
              radius: 20,
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                _previewHeading('Dream Calendar', calendar),
                const SizedBox(height: 20),
                Row(
                    children: ['월', '화', '수', '목', '금', '토', '일']
                        .map((s) => Expanded(
                            child: Text(s,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFFBBBBBB)))))
                        .toList()),
                const SizedBox(height: 12),
                GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 14,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisExtent: 66,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 10),
                    itemBuilder: (_, i) {
                      final day = first.add(Duration(days: i));
                      final record = records
                          .where((r) => sameDate(r.date, day))
                          .firstOrNull;
                      return InkWell(
                          onTap: record == null
                              ? null
                              : () => openDiaryHome(context, record),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(children: [
                            Text('${day.day}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: record == null
                                        ? const Color(0xFFCCCCCC)
                                        : muted)),
                            const SizedBox(height: 8),
                            Opacity(
                                opacity: record == null ? .3 : 1,
                                child: const FigmaAsset('516-783/imgVector3'))
                          ]));
                    }),
              ])),
          gap,
          Paper(
              radius: 20,
              padding: const EdgeInsets.all(15),
              child: Column(children: [
                _previewHeading('Dream Store', shop),
                gap,
                InkWell(
                    onTap: shop,
                    child: const Row(children: [
                      Expanded(
                          child: RecordImage(previewProductImage,
                              height: 136, radius: 10)),
                      SizedBox(width: 16),
                      Expanded(
                          child: RecordImage(previewProductImage,
                              height: 136, radius: 10)),
                    ])),
              ])),
        ]));
  }

  Widget _previewHeading(String title, VoidCallback tap) => Row(children: [
        const FIcon('calendar'),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700))),
        PreviewLink(onTap: tap),
      ]);
}

class PreviewLink extends StatelessWidget {
  final VoidCallback onTap;
  const PreviewLink({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: '전체보기',
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFEAE6FF),
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('전체보기',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: purple)),
                SizedBox(width: 4),
                FIcon('chevron', size: 8)
              ]))));
}

class LumiArt extends StatelessWidget {
  final double width, height;
  const LumiArt({super.key, this.width = 42, this.height = 42});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      height: height,
      child: ClipRect(
          child: Stack(children: [
        Positioned(
            left: -width * .2264,
            top: -height * .7772,
            width: width * 1.41,
            height: height * 2.51,
            child: Image.asset(
                'assets/figma/b73dc5d5-779d-44bf-810e-681b0b65df6f.png',
                fit: BoxFit.fill)),
      ])));
}

class DiaryHomePage extends StatefulWidget {
  final Routine routine;
  final DiaryRecord? selected;
  const DiaryHomePage(
      {super.key, this.routine = Routine.morning, this.selected});
  @override
  State<DiaryHomePage> createState() => _DiaryHomePageState();
}

class _DiaryHomePageState extends State<DiaryHomePage> {
  late Routine routine;
  DiaryRecord? selected;
  bool bookmarks = false;
  int? month;
  @override
  void initState() {
    super.initState();
    routine = widget.routine;
    selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReviewState>();
    final records = state.forRoutine(routine);
    final record = selected != null && records.any((r) => r.id == selected!.id)
        ? records.firstWhere((r) => r.id == selected!.id)
        : records.firstOrNull;
    final marked = records.where((r) => r.marked).toList();
    final months = marked.map((r) => r.date.month).toSet().toList()..sort();
    return ReviewPage(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PageHeader(),
      gap,
      Row(children: [
        Expanded(
            child: Text(routine == Routine.morning ? '내 꿈나라' : '내 일기장',
                style: const TextStyle(
                    fontSize: 28, height: 1.35, fontWeight: FontWeight.w600))),
        IconButton(
            tooltip: '기록 검색',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SearchPage(routine: routine))),
            icon: const FIcon('search')),
        IconButton(
            tooltip: '알림',
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            icon: const FIcon('bell'))
      ]),
      Text(
          routine == Routine.morning
              ? '꿈을 기록하고, AI와 함께 나를 알아가요.'
              : '하루를 기록하고, AI와 함께 나를 알아가요.',
          style: const TextStyle(color: muted, fontSize: 14)),
      gap,
      Row(children: [
        MenuAnchor(
            style: const MenuStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.white),
                minimumSize: WidgetStatePropertyAll(Size(114, 40))),
            menuChildren: [
              MenuItemButton(
                  onPressed: () => setState(() {
                        routine = routine == Routine.morning
                            ? Routine.night
                            : Routine.morning;
                        selected = null;
                        month = null;
                      }),
                  child: Text(routine == Routine.morning ? '나이트루틴' : '모닝루틴',
                      style: const TextStyle(color: purple, fontSize: 13)))
            ],
            builder: (context, controller, _) => SizedBox(
                width: 114,
                height: 40,
                child: OutlinedButton(
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                    style: OutlinedButton.styleFrom(
                        backgroundColor: lavender,
                        side: const BorderSide(color: lineColor),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(routine.label,
                              style: const TextStyle(fontSize: 13)),
                          const FIcon('dropdown', size: 10)
                        ])))),
        const Spacer(),
        _viewButton('캘린더', 'calendar', !bookmarks,
            () => setState(() => bookmarks = false)),
        _viewButton('북마크', 'bookmark', bookmarks,
            () => setState(() => bookmarks = true))
      ]),
      gap,
      if (state.loading) const LinearProgressIndicator(minHeight: 2),
      if (state.error != null) ...[
        InfoBox(state.error!, retry: state.refresh),
        gap
      ],
      if (bookmarks) ...[
        Wrap(spacing: 6, children: [
          ChoiceChip(
              label: Text('전체 ${marked.length}'),
              selected: month == null,
              onSelected: (_) => setState(() => month = null)),
          ...months.map((m) => ChoiceChip(
              label:
                  Text('$m월 ${marked.where((r) => r.date.month == m).length}'),
              selected: month == m,
              onSelected: (_) => setState(() => month = m)))
        ]),
        gap,
        if (marked.isEmpty)
          const InfoBox('북마크한 기록이 없어요. 기록의 북마크 아이콘을 눌러 저장해 보세요.'),
        ...marked
            .where((r) => month == null || r.date.month == month)
            .map((r) => RecordRow(
                record: r,
                onTap: () => setState(() {
                      selected = r;
                      bookmarks = false;
                    }))),
      ] else ...[
        if (records.isNotEmpty)
          SizedBox(
              height: 72,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: records.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    if (index == records.length) {
                      return SizedBox(
                          width: 60,
                          child: OutlinedButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          CalendarPage(routine: routine))),
                              style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(color: lineColor),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18))),
                              child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FIcon('calendar', size: 18),
                                    Text('더보기', style: TextStyle(fontSize: 10))
                                  ])));
                    }
                    final r = records.reversed.toList()[index];
                    final active = record?.id == r.id;
                    return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() => selected = r),
                        child: Container(
                            width: 60,
                            decoration: BoxDecoration(
                                color: active ? lavender : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: active ? purple : lineColor)),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${r.date.month}월',
                                      style: const TextStyle(fontSize: 10)),
                                  Text('${r.date.day}',
                                      style: TextStyle(
                                          fontSize: 24,
                                          height: 1.2,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              active ? Colors.black : muted)),
                                  Text(
                                      [
                                        '월',
                                        '화',
                                        '수',
                                        '목',
                                        '금',
                                        '토',
                                        '일'
                                      ][r.date.weekday - 1],
                                      style: const TextStyle(fontSize: 10))
                                ])));
                  })),
        gap,
        EmotionCard(routine: routine),
        gap,
        if (record != null)
          SummaryCard(record: record)
        else
          const Paper(
              child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text('아직 기록이 없어요.\n루미에게 오늘의 이야기를 들려주세요.',
                      textAlign: TextAlign.center))),
        gap,
        PrimaryButton(routine.recordLabel,
            icon: Icons.add, onPressed: () => openChat(context, routine)),
      ],
    ]));
  }

  Widget _viewButton(
          String label, String icon, bool active, VoidCallback tap) =>
      SizedBox(
          height: 36,
          child: OutlinedButton(
              onPressed: tap,
              style: OutlinedButton.styleFrom(
                  backgroundColor: active ? lavender : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: const BorderSide(color: lineColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Row(children: [
                FIcon(icon, size: 12, color: active ? purple : Colors.black),
                const SizedBox(width: 3),
                Text(label,
                    style: TextStyle(
                        fontSize: 10, color: active ? purple : Colors.black))
              ])));
}

class EmotionCard extends StatelessWidget {
  final Routine routine;
  const EmotionCard({super.key, required this.routine});
  @override
  Widget build(BuildContext context) {
    final demo = context.watch<ReviewState>().preview;
    return Paper(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(routine == Routine.morning ? '꿈 감정 통계' : '하루 감정 통계',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600))),
        PreviewLink(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => EmotionStatisticsPage(routine: routine)))),
      ]),
      const SizedBox(height: 6),
      Text(demo ? '최근 4일간 자주 나타난 감정이에요. (예시)' : '기록을 바탕으로 감정을 돌아보세요.',
          style: const TextStyle(fontSize: 10, color: muted)),
      gap,
      if (demo)
        SizedBox(
            height: 128,
            width: double.infinity,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _ring('행복', '31%', 86, .5, 5),
                  const SizedBox(width: 9),
                  _ring('불안', '42%', 116, 1, 8),
                  const SizedBox(width: 9),
                  _ring('평안', '17%', 58, .25, 3)
                ])))
      else
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: InfoBox(
                '감정 비율은 아직 제공되지 않아요.\nAI 감정 인사이트에서 생성된 리포트를 확인할 수 있어요.')),
    ]));
  }

  Widget _ring(String label, String value, double size, double opacity,
          double border) =>
      Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: purple.withValues(alpha: opacity), width: border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FigmaAsset(size < 70
                ? '409-738/imgVector7'
                : opacity == 1
                    ? '409-738/imgVector6'
                    : '409-738/imgVector5'),
            Text(label, style: TextStyle(fontSize: size < 70 ? 8 : 11)),
            Text(value,
                style: TextStyle(
                    fontSize: size < 70 ? 12 : 17,
                    height: 1.1,
                    color: purple.withValues(alpha: opacity),
                    fontWeight: FontWeight.w600))
          ]));
}

class SummaryCard extends StatelessWidget {
  final DiaryRecord record;
  const SummaryCard({super.key, required this.record});
  @override
  Widget build(BuildContext context) => Paper(
      padding: EdgeInsets.zero,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            if (record.image.isNotEmpty)
              Positioned.fill(child: RecordImage(record.image, radius: 24)),
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
              Colors.white,
              Colors.white.withValues(alpha: .75),
              Colors.white.withValues(alpha: .45)
            ])))),
            Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          record.routine == Routine.morning
                              ? '오늘의 꿈 요약'
                              : '오늘 하루 요약',
                          style: const TextStyle(
                              fontSize: 18,
                              height: 1.35,
                              fontWeight: FontWeight.w600)),
                      gap,
                      ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight:
                                  MediaQuery.textScalerOf(context).scale(14) *
                                      1.35 *
                                      2),
                          child: Text(
                              record.title
                                  .replaceAll(RegExp(r'\s+'), ' ')
                                  .trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  color: purple,
                                  fontWeight: FontWeight.w600))),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight:
                                  MediaQuery.textScalerOf(context).scale(12) *
                                      1.5 *
                                      2),
                          child: Text(
                              record.content.isEmpty
                                  ? '대화를 이어서 기록을 완성해 보세요.'
                                  : record.content
                                      .replaceAll(RegExp(r'\s+'), ' ')
                                      .trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                  color: muted))),
                      const SizedBox(height: 8),
                      Row(children: [
                        FilledButton.tonal(
                            onPressed: () => openAnalysis(context, record),
                            style: FilledButton.styleFrom(
                                backgroundColor: lavender),
                            child: Text(
                                record.routine == Routine.morning
                                    ? 'AI 해석보기  ›'
                                    : 'AI 조언 보기  ›',
                                style: const TextStyle(
                                    color: purple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                        const Spacer(),
                        IconButton(
                            tooltip: record.marked ? '북마크 해제' : '북마크 추가',
                            onPressed: () => markRecord(context, record),
                            icon: Icon(
                                record.marked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: purple,
                                size: 22))
                      ]),
                    ])),
          ])));
}

class RecordRow extends StatelessWidget {
  final DiaryRecord record;
  final VoidCallback onTap;
  const RecordRow({super.key, required this.record, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 127,
                child: RecordImage(record.image, height: 77, radius: 12)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(record.dateLabel,
                      style: const TextStyle(fontSize: 10, color: muted)),
                  Text(record.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Tags(record.tags.take(3).toList())
                ])),
            Column(children: [
              const Padding(
                  padding: EdgeInsets.all(9),
                  child: FIcon('chevron', size: 10)),
              IconButton(
                  tooltip: record.marked ? '북마크 해제' : '북마크 추가',
                  onPressed: () => markRecord(context, record),
                  icon: Icon(
                      record.marked ? Icons.bookmark : Icons.bookmark_outline,
                      size: 19,
                      color: purple))
            ]),
          ])));
}

class CalendarPage extends StatefulWidget {
  final Routine routine;
  const CalendarPage({super.key, this.routine = Routine.morning});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime? month;
  DiaryRecord? selected;
  @override
  Widget build(BuildContext context) {
    final records = context.watch<ReviewState>().forRoutine(widget.routine);
    month ??= records.firstOrNull?.date ?? DateTime.now();
    selected ??= records.firstOrNull;
    final first = DateTime(month!.year, month!.month, 1);
    final days = DateTime(first.year, first.month + 1, 0).day;
    final count = ((first.weekday - 1 + days) / 7).ceil() * 7;
    return ReviewPage(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PageHeader(
          title: 'Dream Calendar', close: false, actions: [FIcon('calendar')]),
      gap,
      Row(children: [
        IconButton(
            tooltip: '이전 달',
            onPressed: () =>
                setState(() => month = DateTime(first.year, first.month - 1)),
            icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: Text('${first.year}년 ${first.month}월',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600))),
        IconButton(
            tooltip: '다음 달',
            onPressed: () =>
                setState(() => month = DateTime(first.year, first.month + 1)),
            icon: const Icon(Icons.chevron_right))
      ]),
      gap,
      Paper(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(
                children: ['월', '화', '수', '목', '금', '토', '일']
                    .map((v) => Expanded(
                        child: Text(v,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontSize: 12, color: muted))))
                    .toList()),
            gap,
            GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: count,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: .72,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 5),
                itemBuilder: (_, index) {
                  final day = index - first.weekday + 2;
                  if (day < 1 || day > days) return const SizedBox.shrink();
                  final date = DateTime(first.year, first.month, day);
                  final record =
                      records.where((r) => sameDate(r.date, date)).firstOrNull;
                  final active =
                      selected != null && sameDate(selected!.date, date);
                  return InkWell(
                      onTap: record == null
                          ? null
                          : () => setState(() => selected = record),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                          decoration: BoxDecoration(
                              color: active ? lavender : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  active ? Border.all(color: purple) : null),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$day',
                                    style: TextStyle(
                                        color: record == null
                                            ? const Color(0xFFCECED3)
                                            : Colors.black,
                                        fontSize: 13)),
                                const SizedBox(height: 6),
                                Opacity(
                                    opacity: record == null ? .25 : 1,
                                    child: const FIcon('smile', size: 21))
                              ])));
                }),
          ])),
      gap,
      if (selected != null &&
          selected!.date.month == first.month &&
          selected!.date.year == first.year) ...[
        Row(children: [
          Expanded(
              child: Text(selected!.dateLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          TextButton(
              onPressed: () => openDiaryHome(context, selected!),
              child: const Text('전체보기  ›'))
        ]),
        SummaryCard(record: selected!),
      ] else
        const InfoBox('기록이 있는 날짜를 선택해 주세요.'),
    ]));
  }
}

class SearchPage extends StatefulWidget {
  final Routine routine;
  const SearchPage({super.key, required this.routine});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim().toLowerCase();
    final results = context
        .watch<ReviewState>()
        .forRoutine(widget.routine)
        .where((r) => '${r.title} ${r.content} ${r.tags.join(' ')}'
            .toLowerCase()
            .contains(query))
        .toList();
    return ReviewPage(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(
            tooltip: '뒤로',
            onPressed: () => goBack(context),
            icon: const FIcon('back')),
        Expanded(
            child: TextField(
                controller: controller,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    hintText: '기록 검색',
                    prefixIcon: const Padding(
                        padding: EdgeInsets.all(14),
                        child: FIcon('search', size: 16, color: purple)),
                    suffixIcon: IconButton(
                        tooltip: '검색어 지우기',
                        onPressed: () => setState(controller.clear),
                        icon: const Icon(Icons.cancel_outlined, size: 18)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12))))
      ]),
      gap,
      const InfoBox('기록의 제목, 내용, 태그에서 검색해요.'),
      const SizedBox(height: 22),
      if (query.length < 2)
        const InfoBox('검색어를 두 글자 이상 입력해 주세요.')
      else ...[
        Text('관련 기록 ${results.length}건',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        if (results.isEmpty) const InfoBox('검색 결과가 없어요. 다른 단어로 검색해 보세요.'),
        ...results.map((r) =>
            RecordRow(record: r, onTap: () => openDiaryHome(context, r))),
      ],
    ]));
  }
}

class AnalysisSectionTitle extends StatelessWidget {
  final String text, asset;
  const AnalysisSectionTitle(this.text, {super.key, required this.asset});
  @override
  Widget build(BuildContext context) => Row(children: [
        FigmaAsset(asset),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 11, color: purple))
      ]);
}

class AnalysisPage extends StatefulWidget {
  final DiaryRecord record;
  const AnalysisPage({super.key, required this.record});
  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  int tab = 0;
  String? report, error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    if (!context.read<ReviewState>().preview) _loadReport();
  }

  Future<void> _loadReport({bool generate = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (generate) {
        await reportService
            .generateReport()
            .timeout(const Duration(seconds: 90));
      }
      final value =
          await reportService.getReport().timeout(const Duration(seconds: 30));
      if (mounted) {
        setState(() => report = value?['weekly_content']?.toString());
      }
    } catch (_) {
      if (mounted) setState(() => error = '리포트를 불러오지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReviewState>();
    final r = widget.record;
    final previous = state.previousNight(r);
    return ReviewPage(
        background: canvas,
        child: Column(children: [
          PageHeader(
              pill: true,
              onClose: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          DiaryHomePage(routine: r.routine, selected: r)),
                  ModalRoute.withName('/home')),
              actions: [
                IconButton(
                    tooltip: '리포트 새로고침',
                    onPressed: busy
                        ? null
                        : () => state.preview ? setState(() {}) : _loadReport(),
                    icon: const FigmaAsset('519-1448/imgIcRoundRefresh')),
                IconButton(
                    tooltip: r.marked ? '북마크 해제' : '북마크 추가',
                    onPressed: () => markRecord(context, r),
                    icon: r.marked
                        ? const FigmaAsset('519-1448/imgVector')
                        : const FIcon('bookmark'))
              ]),
          gap,
          Paper(
              radius: 16,
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700)),
                    gap,
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: lavender,
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const FigmaAsset('519-1448/imgVector1'),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: Text(r.dateLabel,
                                      style: const TextStyle(fontSize: 12))),
                              const SizedBox(width: 14),
                              if (r.routine == Routine.morning)
                                const FigmaAsset('519-1448/imgVector2')
                              else
                                const Icon(Icons.wb_sunny_outlined,
                                    size: 14, color: purple),
                              const SizedBox(width: 6),
                              Text(r.routine == Routine.morning ? '꿈' : '하루',
                                  style: const TextStyle(fontSize: 12)),
                            ])),
                    gap,
                    Row(
                        children: List.generate(
                            3,
                            (i) => Expanded(
                                child: InkWell(
                                    onTap: () => setState(() => tab = i),
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        decoration: BoxDecoration(
                                            color: tab == i
                                                ? lavender
                                                : Colors.white,
                                            border: Border.all(
                                                color: lineColor, width: .7)),
                                        child: Text(
                                            ['AI 요약', '전문 보기', 'AI 감정 인사이트'][i],
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: tab == i
                                                    ? purple
                                                    : muted))))))),
                    const SizedBox(height: 20),
                    if (tab != 2) ...[
                      RecordImage(r.image, height: 112),
                      if (tab == 0) ...[
                        const SizedBox(height: 20),
                        const AnalysisSectionTitle('꿈 핵심 키워드',
                            asset: '519-1448/imgFrame473'),
                        gap,
                        Tags(r.tags),
                      ],
                      gap,
                      const Divider(),
                      gap
                    ],
                    if (tab == 0) ...[
                      AnalysisSectionTitle(state.preview ? 'AI 해석' : 'AI 요약',
                          asset: '519-1448/imgFrame474'),
                      gap,
                      Text(
                          state.preview
                              ? '이 꿈은 새로운 환경이나 변화 앞에서 느끼는 긴장과 적응에 대한 심리가 반영된 것으로 보여요.\n낯선 사람들은 새로운 시작에 대한 기대와 아직 익숙하지 않은 상황에서 오는 불안감을 상징할 수 있습니다.\n조금씩 자신의 자리를 찾아가고 있다는 긍정적인 신호로 해석할 수 있어요.'
                              : r.content.isEmpty
                                  ? '아직 생성된 일기가 없어요. 대화를 이어가며 기록을 완성해 주세요.'
                                  : r.content
                                      .split('\n')
                                      .where((s) => s.trim().isNotEmpty)
                                      .take(2)
                                      .join('\n\n'),
                          style: const TextStyle(fontSize: 11, height: 1.7)),
                      gap,
                      const Divider(),
                      gap,
                      const AnalysisSectionTitle('오늘의 조언',
                          asset: '519-1448/imgFrame482'),
                      gap,
                      if (state.preview)
                        const InfoBox(
                            '새로운 환경에 대한 긴장과 기대가 함께 드러나요.\n나만의 속도로 새로운 시작을 준비해 보세요. (예시)')
                      else
                        const InfoBox(
                            '생성된 일기 본문을 요약해 보여드려요. 별도의 꿈 해석은 아직 제공되지 않아요.'),
                      gap,
                      PrimaryButton('대화 이어하기',
                          height: 40,
                          radius: 20,
                          onPressed: () => openChat(context, r.routine, r)),
                    ] else if (tab == 1) ...[
                      AnalysisSectionTitle(
                          r.routine == Routine.morning ? '꿈 전문 보기' : '하루 전문 보기',
                          asset: '519-1448/imgFrame474'),
                      gap,
                      Text(r.content.isEmpty ? '아직 작성된 본문이 없어요.' : r.content,
                          style: const TextStyle(fontSize: 12, height: 1.8)),
                    ] else ...[
                      if (r.routine == Routine.morning) ...[
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(children: [
                                const FigmaAsset('731-135/imgMoonWrap'),
                                const Text('어제 하루',
                                    style: TextStyle(fontSize: 11)),
                                gap,
                                Tags(previous?.tags ?? const [])
                              ]),
                              const FigmaAsset('731-135/imgVector3'),
                              Column(children: [
                                const FigmaAsset('731-135/imgGroup'),
                                const Text('이 꿈',
                                    style: TextStyle(fontSize: 11)),
                                gap,
                                Tags(r.tags)
                              ])
                            ]),
                        gap,
                        if (previous == null)
                          const InfoBox(
                              '전날 하루 기록 없음\n전날의 하루를 기록하면 꿈과 함께 돌아볼 수 있어요.')
                        else ...[
                          const InfoBox('어제의 하루 기록과 오늘의 꿈을 함께 살펴보세요.'),
                          gap,
                          TextButton(
                              onPressed: () => openDiaryHome(context, previous),
                              child: Text(
                                  '${previous.date.month}월 ${previous.date.day}일 나이트루틴 보기  ›'))
                        ],
                        const Divider(),
                        gap,
                      ],
                      const Text('AI 감정 리포트',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      gap,
                      if (busy)
                        const Center(child: CircularProgressIndicator())
                      else if (state.preview)
                        const InfoBox(
                            '어제 하루의 ‘불안’이 오늘 꿈에서도 이어졌어요.\n하지만 ‘기대’와 ‘설렘’이 함께 나타나며 새로운 시작에 대한 긍정적인 에너지도 느껴져요. (예시)')
                      else if (error != null)
                        InfoBox(error!, retry: _loadReport)
                      else if (report != null)
                        Text(report!,
                            style: const TextStyle(fontSize: 13, height: 1.8))
                      else
                        const InfoBox('아직 생성된 감정 리포트가 없어요.'),
                      gap,
                      if (!state.preview)
                        PrimaryButton('최근 기록으로 리포트 생성',
                            onPressed: busy
                                ? null
                                : () => _loadReport(generate: true)),
                    ],
                  ])),
        ]));
  }
}
