import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../config/api.dart';
import 'review_state.dart';
import 'figma_assets.dart';

const purple = Color(0xFF6E63FF);
const lavender = Color(0xFFF5F2FF);
const canvas = Color(0xFFF8F8FF);
const lineColor = Color(0xFFDCD7FF);
const muted = Color(0xFF888888);
const gap = SizedBox(height: 12);
const gutter = 24.0;

ThemeData reviewTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
          seedColor: purple, primary: purple, surface: Colors.white),
      textTheme: const TextTheme(
          bodyMedium:
              TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF171717))),
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0),
      dividerTheme: const DividerThemeData(color: lineColor, thickness: .7),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lavender,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: lineColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: lineColor))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))),
    );

const iconFiles = <String, String>{
  'close': 'd0d8c677-2586-486a-9850-005415f798eb.svg',
  'search': '13661f43-80a5-4b45-a7d4-9bee4af0e5dc.svg',
  'bell': 'bd5572fc-65c3-49ea-8438-3b66085d3b6c.svg',
  'calendar': '336aa982-4e1e-461f-b0ad-75b2fb0bdbf7.svg',
  'bookmark': '7b27a11f-718c-4f7f-9a36-ad3323ffa685.svg',
  'chevron': '809ca412-1114-437c-81da-5ef5917b3d89.svg',
  'dropdown': '6dc6cbff-76e7-4c82-8ac7-166870fe6a94.svg',
  'home': '48d002cc-da37-45c7-8e17-c2df62c88b1d.svg',
  'chat': 'e99af228-c626-4e69-8f03-d61388d4fcf4.svg',
  'store': 'eec519f3-6d84-440f-8311-0f52eeed64f5.svg',
  'settings': '7153013e-f425-478e-91f7-3bc36d97e2d5.svg',
  'smile': 'fce8d0c4-6ef7-440b-8da4-f5d96d5b5508.svg',
  'back': 'b50f70fe-20ab-4faa-ac65-cb12df298220.svg',
};

class FigmaAsset extends StatelessWidget {
  final String reference;
  final Color? color;
  const FigmaAsset(this.reference, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final asset = figmaAssets[reference]!;
    return SizedBox(
        width: asset.width,
        height: asset.height,
        child: SvgPicture.asset(asset.path,
            colorFilter: color == null
                ? null
                : ColorFilter.mode(color!, BlendMode.srcIn)));
  }
}

class FIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const FIcon(this.name, {super.key, this.size = 20, this.color});
  @override
  Widget build(BuildContext context) {
    final reference = figmaAssets.entries
        .firstWhere((e) => e.value.path.endsWith(iconFiles[name]!))
        .key;
    return SizedBox(
        width: size,
        height: size,
        child: FittedBox(
            fit: BoxFit.scaleDown, child: FigmaAsset(reference, color: color)));
  }
}

class ReviewPage extends StatelessWidget {
  final Widget child;
  final int? tab;
  final Widget? footer;
  final Color background;
  final bool scroll;
  final double horizontalPadding;
  const ReviewPage(
      {super.key,
      required this.child,
      this.tab,
      this.footer,
      this.background = Colors.white,
      this.scroll = true,
      this.horizontalPadding = gutter});
  @override
  Widget build(BuildContext context) {
    final demo = context.watch<ReviewState>().preview;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
          child: Column(children: [
        if (demo)
          Container(
              width: double.infinity,
              color: lavender,
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: const Text('디자인 미리보기 · 예시 데이터',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: purple))),
        Expanded(
            child: scroll
                ? SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 8, horizontalPadding, 20),
                    child: child)
                : Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 8, horizontalPadding, 12),
                    child: child)),
        if (footer != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 12),
              child: footer!),
      ])),
      bottomNavigationBar: tab == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                  height: 64,
                  color: Colors.white,
                  child: Row(
                      children: List.generate(
                          4,
                          (i) => Expanded(
                              child: InkWell(
                                  onTap: () {
                                    if (i != tab) {
                                      Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          [
                                            '/home',
                                            '/dream_list',
                                            '/store',
                                            '/settings'
                                          ][i],
                                          (r) => false);
                                    }
                                  },
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        FIcon(
                                            [
                                              'home',
                                              'chat',
                                              'store',
                                              'settings'
                                            ][i],
                                            size: 29,
                                            color: i == tab
                                                ? purple
                                                : const Color(0xFFCCCCCC)),
                                        const SizedBox(height: 3),
                                        Text(['홈', 'AI-채팅', '스토어', '설정'][i],
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: i == tab
                                                    ? purple
                                                    : Colors.black)),
                                      ]))))))),
    );
  }
}

void goBack(BuildContext context) {
  if (Navigator.canPop(context)) {
    Navigator.pop(context);
  } else {
    Navigator.pushReplacementNamed(context, '/home');
  }
}

class PageHeader extends StatelessWidget {
  final String? title;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final bool close, leading;
  final bool pill;
  const PageHeader(
      {super.key,
      this.title,
      this.actions = const [],
      this.onClose,
      this.close = true,
      this.leading = true,
      this.pill = false});
  @override
  Widget build(BuildContext context) => Container(
      height: 40,
      decoration: pill
          ? BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20))
          : null,
      child: Stack(alignment: Alignment.center, children: [
        if (title != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700))),
        Row(children: [
          if (leading)
            IconButton(
                tooltip: close ? '닫기' : '뒤로',
                padding: EdgeInsets.zero,
                onPressed: onClose ?? () => goBack(context),
                icon: FIcon(close ? 'close' : 'back', size: close ? 40 : 20)),
          const Spacer(),
          ...actions,
        ])
      ]));
}

class Paper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  const Paper(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.radius = 24,
      this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [
            BoxShadow(color: Color(0x207165F6), blurRadius: 27)
          ]),
      child: Material(type: MaterialType.transparency, child: child));
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final IconData? icon;
  final double height, radius;
  const PrimaryButton(this.label,
      {super.key,
      this.onPressed,
      this.outlined = false,
      this.icon,
      this.height = 56,
      this.radius = 28});
  @override
  Widget build(BuildContext context) {
    final content = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
      Flexible(
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600)))
    ]);
    return SizedBox(
        width: double.infinity,
        height: height,
        child: outlined
            ? OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: purple),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius))),
                child: content)
            : FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius))),
                child: content));
  }
}

class RecordImage extends StatelessWidget {
  final String source;
  final double? height;
  final double radius;
  final BoxFit fit;
  const RecordImage(this.source,
      {super.key, this.height, this.radius = 16, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    Widget empty() => Container(
        height: height,
        color: const Color(0xFFF4F4F6),
        child: const Center(
            child: Icon(Icons.image_outlined, color: muted, size: 36)));
    final path = source == previewProductImage
        ? 'assets/figma/188107ea-a224-4fe1-aa06-708975b55370.png'
        : source;
    return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: path.isEmpty
            ? empty()
            : path.startsWith('assets/')
                ? Image.asset(path,
                    height: height,
                    width: double.infinity,
                    fit: fit,
                    errorBuilder: (_, __, ___) => empty())
                : Image.network(Api.imageUrl(path),
                    height: height,
                    width: double.infinity,
                    fit: fit,
                    errorBuilder: (_, __, ___) => empty()));
  }
}

class InfoBox extends StatelessWidget {
  final String text;
  final VoidCallback? retry;
  const InfoBox(this.text, {super.key, this.retry});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: lavender, borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: const TextStyle(color: purple, fontSize: 13)),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('다시 시도'))
      ]));
}

class Tags extends StatelessWidget {
  final List<String> tags;
  const Tags(this.tags, {super.key});
  @override
  Widget build(BuildContext context) => Wrap(
      spacing: 5,
      runSpacing: 5,
      children: tags
          .map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                  color: lavender,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: lineColor)),
              child: Text(tag,
                  style: const TextStyle(fontSize: 10, color: purple))))
          .toList());
}

Future<void> markRecord(BuildContext context, DiaryRecord record) async {
  try {
    await context.read<ReviewState>().toggleMarked(record);
  } catch (_) {
    if (context.mounted) message(context, '북마크를 저장하지 못했어요. 다시 시도해 주세요.');
  }
}

void message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
String won(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
