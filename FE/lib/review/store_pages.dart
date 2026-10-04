import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/store_service.dart';
import 'design.dart';
import 'review_state.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String category = '다이어리';
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await context.read<ReviewState>().loadProducts();
    } catch (_) {
      if (mounted) setState(() => error = '상품을 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = context
        .watch<ReviewState>()
        .products
        .where((p) => p.category == category)
        .toList();
    return ReviewPage(
        tab: 2,
        horizontalPadding: 30,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PageHeader(leading: false, actions: [
            IconButton(
                tooltip: '장바구니',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CartPage())),
                icon: const Icon(Icons.shopping_cart_outlined, color: purple))
          ]),
          gap,
          const Row(children: [
            FIcon('calendar'),
            SizedBox(width: 10),
            Text('Dream Store',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))
          ]),
          const SizedBox(height: 32),
          Wrap(
              spacing: 8,
              children: ['다이어리', '악세서리', '기타']
                  .map((c) => ChoiceChip(
                      label: Text(c),
                      selected: category == c,
                      onSelected: (_) => setState(() => category = c),
                      selectedColor: purple,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                          color: category == c ? Colors.white : purple,
                          fontSize: 12),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: lineColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))))
                  .toList()),
          const SizedBox(height: 32),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            InfoBox(error!, retry: _load)
          else if (items.isEmpty)
            const InfoBox('등록된 상품이 없어요.')
          else
            LayoutBuilder(
                builder: (context, constraints) => GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 204),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ProductPage(item: item))),
                          child: Paper(
                              radius: 16,
                              padding: const EdgeInsets.all(12),
                              child: Column(children: [
                                RecordImage(item.image, height: 98, radius: 4),
                                gap,
                                Text(item.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12)),
                                const Spacer(),
                                Text(won(item.price),
                                    style: const TextStyle(
                                        fontSize: 12, color: muted))
                              ])));
                    })),
        ]));
  }
}

class ProductPage extends StatefulWidget {
  final ShopItem item;
  const ProductPage({super.key, required this.item});
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late ShopItem item;
  bool adding = false;
  String? error;
  @override
  void initState() {
    super.initState();
    item = widget.item;
    _load();
  }

  Future<void> _load() async {
    if (context.read<ReviewState>().preview) return;
    try {
      final data = await storeService
          .getItemDetail(item.id)
          .timeout(const Duration(seconds: 30));
      if (mounted && data != null) {
        setState(() {
          item = ShopItem.fromJson(data, item.category);
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = '상세 설명을 불러오지 못했어요.');
    }
  }

  Future<void> _add({bool checkout = false}) async {
    if (adding) return;
    setState(() => adding = true);
    try {
      await context.read<ReviewState>().addToCart(item);
      if (!mounted) return;
      if (checkout) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const CartPage()));
      } else {
        message(context, '장바구니에 담았어요.');
      }
    } catch (_) {
      if (mounted) message(context, '장바구니 저장에 실패했어요.');
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  @override
  Widget build(BuildContext context) => ReviewPage(
      footer: Row(children: [
        Expanded(
            child: PrimaryButton('장바구니',
                height: 40,
                radius: 10,
                outlined: true,
                onPressed: adding ? null : _add)),
        const SizedBox(width: 10),
        Expanded(
            child: PrimaryButton('구매하기',
                height: 40,
                radius: 10,
                onPressed: adding ? null : () => _add(checkout: true)))
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageHeader(close: false, actions: [
          IconButton(
              tooltip: '장바구니 보기',
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const CartPage())),
              icon: const Icon(Icons.shopping_cart_outlined))
        ]),
        gap,
        RecordImage(item.image, height: 300, radius: 20),
        const SizedBox(height: 24),
        Text(item.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(won(item.price),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: purple)),
        gap,
        Tags([item.category]),
        const SizedBox(height: 24),
        Paper(
            radius: 16,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('상품 소개',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              gap,
              if (error != null)
                InfoBox(error!, retry: _load)
              else
                Text(
                    item.description.isEmpty
                        ? '상품의 상세 설명을 준비하고 있어요.'
                        : item.description,
                    style: const TextStyle(
                        fontSize: 13, color: muted, height: 1.8))
            ])),
      ]));
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReviewState>();
    final all = state.cart.isNotEmpty && state.cart.every((l) => l.selected);
    return ReviewPage(
        tab: 2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PageHeader(title: '장바구니', close: false),
          gap,
          const Text('장바구니',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const Text('마음에 담은 꿈을 만나보세요.', style: TextStyle(color: muted)),
          const SizedBox(height: 24),
          if (state.cart.isEmpty)
            const Paper(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 44),
                    child: Center(
                        child: Text('장바구니가 비어 있어요.',
                            style: TextStyle(color: muted)))))
          else
            Paper(
                radius: 14,
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Checkbox(
                        value: all,
                        onChanged: (v) {
                          for (final l in state.cart) {
                            l.selected = v ?? false;
                          }
                          state.saveCart();
                        }),
                    const Text('전체 선택', style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    TextButton(
                        onPressed: state.clearCart,
                        child: const Text('전체 삭제',
                            style: TextStyle(color: muted, fontSize: 12)))
                  ]),
                  ...state.cart.map((l) => Column(children: [
                        const Divider(),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(children: [
                              SizedBox(
                                  width: 28,
                                  child: Checkbox(
                                      value: l.selected,
                                      onChanged: (v) {
                                        l.selected = v ?? false;
                                        state.saveCart();
                                      })),
                              const SizedBox(width: 6),
                              SizedBox(
                                  width: 75,
                                  child: RecordImage(l.item.image,
                                      height: 83, radius: 6)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(l.item.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text('${l.quantity}개',
                                        style: const TextStyle(
                                            color: muted, fontSize: 12)),
                                    Text(won(l.item.price * l.quantity),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600))
                                  ])),
                              IconButton(
                                  tooltip: '${l.item.name} 삭제',
                                  onPressed: () =>
                                      state.removeFromCart(l.item.id),
                                  icon: const Icon(Icons.close,
                                      size: 18, color: muted)),
                            ]))
                      ])),
                ])),
          const SizedBox(height: 24),
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: lavender, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _price('선택 상품 금액', won(state.subtotal)),
                gap,
                _price('배송비', '주문 시 안내'),
                const Divider(height: 26),
                _price('상품 합계', won(state.total), bold: true),
              ])),
          gap,
          PrimaryButton('구매하기',
              height: 40,
              radius: 10,
              onPressed: state.cart.any((l) => l.selected)
                  ? () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                              title: const Text('주문 안내'),
                              content: const Text(
                                  '상품을 장바구니에 저장했어요.\n현재 앱에는 결제 기능이 연결되어 있지 않아 주문이나 결제는 진행되지 않아요.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('확인'))
                              ]))
                  : null),
        ]));
  }

  Widget _price(String label, String amount, {bool bold = false}) =>
      Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400))),
        Text(amount,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400))
      ]);
}
