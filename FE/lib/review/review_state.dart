import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_service.dart';

enum Routine { morning, night }

extension RoutineLabel on Routine {
  String get label => this == Routine.morning ? '모닝루틴' : '나이트루틴';
  String get apiValue => this == Routine.morning ? 'Morning' : 'Night';
  String get recordLabel => this == Routine.morning ? '꿈 기록하기' : '오늘 하루 기록하기';
}

class DiaryRecord {
  final int id;
  final DateTime date;
  final Routine routine;
  final String title, content, image;
  final List<String> tags;
  bool marked;
  DiaryRecord(
      {required this.id,
      required this.date,
      required this.routine,
      required this.title,
      required this.content,
      this.image = '',
      this.tags = const [],
      this.marked = false});
  factory DiaryRecord.fromJson(Map<String, dynamic> json) => DiaryRecord(
        id: (json['room_id'] as num).toInt(),
        date: DateTime.tryParse('${json['created_at'] ?? json['updated_at']}')
                ?.toLocal() ??
            DateTime(1970),
        routine: '${json['routine_type']}'.toLowerCase() == 'night'
            ? Routine.night
            : Routine.morning,
        title: json['title']?.toString() ?? '작성 중인 기록',
        content: json['content']?.toString() ?? '',
        image: json['image_url']?.toString() ?? '',
        tags: json['tags'] is List
            ? List<String>.from(json['tags'])
            : '${json['tags'] ?? ''}'
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
        marked: json['is_marked'] == true,
      );
  String get dateLabel => '${date.year}년 ${date.month}월 ${date.day}일';
}

bool sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class ReviewState extends ChangeNotifier {
  bool preview = false, loading = false;
  bool guest = false;
  String? error;
  String account = '';
  List<DiaryRecord> records = [];
  final Set<int> marking = {};
  List<DiaryRecord> forRoutine(Routine routine) =>
      records.where((r) => r.routine == routine).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  DiaryRecord? previousNight(DiaryRecord record) {
    final day =
        DateTime(record.date.year, record.date.month, record.date.day - 1);
    for (final r in records) {
      if (r.routine == Routine.night && sameDate(r.date, day)) return r;
    }
    return null;
  }

  Future<void> start({bool demo = false, bool asGuest = false}) async {
    guest = asGuest;
    preview = demo;
    records = [];
    error = null;
    final prefs = await SharedPreferences.getInstance();
    account = prefs.getString('user_id') ?? '';
    if (demo) {
      for (final day in [6, 8, 12, 13, 20]) {
        records.add(DiaryRecord(
            id: -day,
            date: DateTime(2026, 4, day),
            routine: Routine.morning,
            title: {
              6: '꿈 속의 꿈',
              8: '끝나지 않는 복도',
              12: '지진 난 날 자각몽',
              13: '고등학교 입학하는 꿈',
              20: '새로운 시작'
            }[day]!,
            content:
                '체육관에 앉아 있었다.\n입학식이라고 했는데, 이상하게도 주변이 전부 낯설었다.\n\n분명히 고등학교인데 교복은 내가 알던 색이 아니었고, 옆에 앉은 사람들도 기억이 나지 않았다.\n\n조금 불안했지만, 어딘가 새로운 시작이라는 기대가 느껴졌다.',
            image: previewDreamImage,
            tags: const ['불안', '낯선 곳', '입학식'],
            marked: true));
      }
      for (final day in [6, 8, 12, 20]) {
        records.add(DiaryRecord(
            id: -100 - day,
            date: DateTime(2026, 4, day),
            routine: Routine.night,
            title: '새로운 하루를 준비하며',
            content: '새로운 만남을 앞두고 조금 긴장했다.\n오늘의 작은 성취를 기억하며 편안하게 하루를 마무리한다.',
            image: previewDreamImage,
            tags: const ['피곤', '불안'],
            marked: true));
      }
      notifyListeners();
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (preview) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final values = await sessionService
          .getAllSessions(account)
          .timeout(const Duration(seconds: 35));
      records = values
          .map((e) => DiaryRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      error = '기록을 불러오지 못했어요. 연결을 확인하고 다시 시도해 주세요.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> toggleMarked(DiaryRecord r) async {
    if (!marking.add(r.id)) return;
    notifyListeners();
    try {
      r.marked = preview
          ? !r.marked
          : await sessionService
              .setMarked(r.id, !r.marked)
              .timeout(const Duration(seconds: 20));
    } finally {
      marking.remove(r.id);
      notifyListeners();
    }
  }
}

const previewDreamImage =
    'assets/figma/cc6874b1-405f-44fd-adb1-e94e5bb6725a.png';
