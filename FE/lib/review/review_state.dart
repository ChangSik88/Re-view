import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_service.dart';
import '../services/store_service.dart';

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

class ShopItem {
  final int id, price;
  final String name, image, description, category;
  ShopItem(
      {required this.id,
      required this.name,
      required this.price,
      this.image = '',
      this.description = '',
      this.category = '다이어리'});
  factory ShopItem.fromJson(Map<String, dynamic> j, [String? category]) =>
      ShopItem(
          id: (j['item_id'] as num).toInt(),
          name: '${j['item_name'] ?? '상품'}',
          price: (j['price'] as num?)?.toInt() ?? 0,
          image: '${j['image_url'] ?? ''}',
          description: '${j['description'] ?? j['headline'] ?? ''}',
          category: category ?? '${j['category'] ?? '다이어리'}');
  Map<String, dynamic> toJson() => {
        'item_id': id,
        'item_name': name,
        'price': price,
        'image_url': image,
        'description': description,
        'category': category
      };
}

class CartLine {
  final ShopItem item;
  int quantity;
  bool selected;
  CartLine(this.item, {this.quantity = 1, this.selected = true});
}

bool sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class ReviewState extends ChangeNotifier {
  bool preview = false, loading = false;
  bool guest = false;
  String? error;
  String account = '';
  List<DiaryRecord> records = [];
  List<ShopItem> products = [];
  final List<CartLine> cart = [];
  final Set<int> marking = {};
  Future<void> _cartWrite = Future.value();
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
    products = [];
    cart.clear();
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
      products = [
        ShopItem(
            id: -1,
            name: '드림 다이어리 (날짜별)',
            price: 8900,
            image: previewProductImage,
            description: '꿈의 내용과 감정을 함께 기록하는 나만의 다이어리입니다.'),
        ShopItem(
            id: -2,
            name: '드림 다이어리 (개수별)',
            price: 8900,
            image: previewProductImage),
        ShopItem(id: -3, name: '드림 캐처', price: 12900, category: '악세서리')
      ];
      notifyListeners();
      return;
    }
    try {
      final saved =
          jsonDecode(prefs.getString('review_cart_$account') ?? '[]') as List;
      cart.addAll(saved.map((j) => CartLine(
          ShopItem.fromJson(Map<String, dynamic>.from(j['item'])),
          quantity: j['quantity'] as int,
          selected: j['selected'] == true)));
    } catch (_) {/* A corrupt local cart must not prevent opening the app. */}
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

  Future<void> loadProducts() async {
    if (preview) return;
    final result =
        await storeService.getItems().timeout(const Duration(seconds: 30));
    products = result.entries
        .expand((entry) => (entry.value as List).map(
            (j) => ShopItem.fromJson(Map<String, dynamic>.from(j), entry.key)))
        .toList();
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

  int get subtotal => cart
      .where((l) => l.selected)
      .fold(0, (sum, l) => sum + l.item.price * l.quantity);
  int get delivery =>
      0; // No shipping tariff is available from the current catalog API.
  int get total => subtotal + delivery;
  Future<void> addToCart(ShopItem item) async {
    final index = cart.indexWhere((l) => l.item.id == item.id);
    if (index < 0) {
      cart.add(CartLine(item));
    } else {
      cart[index].quantity++;
    }
    await saveCart();
  }

  Future<void> removeFromCart(int id) async {
    cart.removeWhere((l) => l.item.id == id);
    await saveCart();
  }

  Future<void> clearCart() async {
    cart.clear();
    await saveCart();
  }

  Future<void> saveCart() {
    notifyListeners();
    if (preview) return Future.value();
    final key = 'review_cart_$account';
    final snapshot = jsonEncode(cart
        .map((l) => {
              'item': l.item.toJson(),
              'quantity': l.quantity,
              'selected': l.selected
            })
        .toList());
    _cartWrite = _cartWrite.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, snapshot);
    });
    return _cartWrite;
  }
}

const previewDreamImage =
    'assets/figma/cc6874b1-405f-44fd-adb1-e94e5bb6725a.png';
// Figma product asset is filled from the downloaded manifest in the UI.
const previewProductImage = 'figma-product';
