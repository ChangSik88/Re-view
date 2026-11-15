import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'design.dart';
import 'review_state.dart';

const _danger = Color(0xFFE8444F);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final flags = [true, true, false];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < flags.length; i++) {
        flags[i] = prefs.getBool('review_notification_$i') ?? flags[i];
      }
    });
  }

  Future<void> _set(int index, bool value) async {
    setState(() => flags[index] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('review_notification_$index', value);
  }

  /// 저장된 로그인 정보를 지우고 로그인 화면으로 돌아간다.
  Future<void> _leave(bool preview) async {
    if (!preview) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.remove('user_id');
      await prefs.remove('auto_login');
    }
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Future<void> _confirmWithdraw() async {
    final ok = await showDialog<bool>(
        context: context, builder: (_) => const _WithdrawDialog());
    if (ok != true || !mounted) return;
    try {
      await authService.deleteAccount().timeout(const Duration(seconds: 30));
    } catch (_) {
      if (mounted) message(context, '탈퇴하지 못했어요. 연결을 확인하고 다시 시도해 주세요.');
      return;
    }
    await _leave(false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReviewState>();
    return ReviewPage(
        tab: 2,
        horizontalPadding: 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          const Text('설정',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const Text('계정과 알림을 관리해요.',
              style: TextStyle(color: muted, fontSize: 16)),
          gap,
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: lavender,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: lineColor)),
              child: Row(children: [
                const CircleAvatar(
                    backgroundColor: Color(0xFFEDE8FF),
                    radius: 28,
                    child: FigmaAsset('734-135/imgIconUser')),
                const SizedBox(width: 18),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(state.preview ? '미리보기 사용자' : state.account,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      Text(state.preview ? '예시 계정' : '로그인된 계정',
                          style: const TextStyle(color: muted, fontSize: 12))
                    ]))
              ])),
          const SizedBox(height: 24),
          const Text('알림', style: TextStyle(color: muted, fontSize: 13)),
          gap,
          Paper(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                  children: List.generate(
                      3,
                      (i) => Column(children: [
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                secondary: FigmaAsset('734-135/${[
                                  'imgIconClock',
                                  'imgIconFile',
                                  'imgIconCal'
                                ][i]}'),
                                title: Text(['루틴 리마인더', '리포트 완성', '주간 요약'][i],
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    [
                                      '꿈·하루 기록 알림 설정',
                                      '새 리포트 알림 설정',
                                      '매주 요약 알림 설정'
                                    ][i],
                                    style: const TextStyle(
                                        fontSize: 11, color: muted)),
                                value: flags[i],
                                onChanged: (value) => _set(i, value)),
                            if (i < 2) const Divider(height: 1),
                          ])))),
          gap,
          const Text('알림 설정은 이 기기에 저장돼요. 푸시 알림 발송은 아직 연결되지 않았어요.',
              style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 24),
          const Text('약관 및 정책', style: TextStyle(fontSize: 13, color: muted)),
          gap,
          Paper(
              radius: 20,
              padding: EdgeInsets.zero,
              child: Column(
                  children: ['이용약관', '개인정보 처리방침', '약관 동의 이력']
                      .map((title) => ListTile(
                          leading: FigmaAsset('734-135/${switch (title) {
                            '개인정보 처리방침' => 'imgIconShield',
                            '약관 동의 이력' => 'imgIconHistory',
                            _ => 'imgIconFile'
                          }}'),
                          title:
                              Text(title, style: const TextStyle(fontSize: 14)),
                          trailing:
                              const Icon(Icons.chevron_right, color: muted),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => InformationPage(
                                      title: title,
                                      text:
                                          '현재 서버에서 제공하는 $title 정보가 없어요. 문서가 등록되면 여기에서 확인할 수 있어요.')))))
                      .toList())),
          const SizedBox(height: 24),
          const Text('계정', style: TextStyle(color: muted)),
          gap,
          Paper(
              radius: 20,
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                    leading: const FigmaAsset('734-135/imgIconLogout'),
                    title: Text(state.preview ? '미리보기 종료' : '로그아웃'),
                    trailing: const Icon(Icons.chevron_right, color: muted),
                    onTap: () => _leave(state.preview)),
                if (!state.preview) ...[
                  const Divider(height: 1),
                  ListTile(
                      leading: const Icon(Icons.person_remove_outlined,
                          color: _danger),
                      title:
                          const Text('회원 탈퇴', style: TextStyle(color: _danger)),
                      trailing: const Icon(Icons.chevron_right, color: muted),
                      onTap: _confirmWithdraw),
                ],
              ])),
        ]));
  }
}

class InformationPage extends StatelessWidget {
  final String title, text;
  const InformationPage({super.key, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => ReviewPage(
          child: Column(children: [
        PageHeader(title: title, close: false),
        gap,
        InfoBox(text)
      ]));
}

class _WithdrawDialog extends StatelessWidget {
  const _WithdrawDialog();
  @override
  Widget build(BuildContext context) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFFFEBEC),
                child: Icon(Icons.warning_amber_rounded,
                    color: _danger, size: 28)),
            const SizedBox(height: 16),
            const Text('정말 탈퇴하시겠어요?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text('탈퇴하면 모든 꿈·하루 기록과 리포트가 삭제되고\n되돌릴 수 없어요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: muted, height: 1.5)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: PrimaryButton('취소',
                      outlined: true,
                      height: 48,
                      radius: 14,
                      onPressed: () => Navigator.pop(context, false))),
              const SizedBox(width: 12),
              Expanded(
                  child: SizedBox(
                      height: 48,
                      child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: _danger,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('탈퇴하기',
                              style: TextStyle(fontWeight: FontWeight.w600))))),
            ]),
          ])));
}
