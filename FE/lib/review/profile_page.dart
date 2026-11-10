import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import 'review_state.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const path = '/users/me';
  final name = TextEditingController(), birth = TextEditingController();
  Map<String, dynamic>? profile;
  String? gender, error;
  bool busy = false;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { name.dispose(); birth.dispose(); super.dispose(); }

  void fill(dynamic data) {
    profile = Map<String, dynamic>.from(data['result']);
    name.text = profile!['name'];
    birth.text = profile!['birth'] ?? '';
    gender = profile!['gender'];
  }

  Future<void> load() async {
    try {
      final data = await apiClient.get(path);
      if (mounted) setState(() { fill(data); error = null; });
    } catch (_) { if (mounted) setState(() => error = '프로필을 불러오지 못했습니다.'); }
  }

  Future<void> save() async {
    final changes = <String, dynamic>{};
    final date = birth.text.trim().isEmpty ? null : birth.text.trim();
    if (name.text.trim() != profile!['name']) changes['name'] = name.text.trim();
    if (date != profile!['birth']) changes['birth'] = date;
    if (gender != profile!['gender']) changes['gender'] = gender;
    if (changes.isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      final data = await apiClient.patch(path, body: changes);
      if (mounted) { setState(() => fill(data)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장했습니다.'))); }
    } catch (_) { if (mounted) setState(() => error = '저장하지 못했습니다. 이름과 날짜 형식을 확인해 주세요.'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> withdraw() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('회원 탈퇴'), content: const Text('탈퇴하면 이 계정으로 다시 로그인할 수 없습니다. 탈퇴할까요?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('탈퇴'))]));
    if (confirmed != true || !mounted) return;
    setState(() {busy = true; error = null;});
    try {
      await apiClient.delete(path);
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['jwt_token','user_id','auto_login']) { await prefs.remove(key); }
      if (!mounted) return;
      await context.read<ReviewState>().start(demo: true, asGuest: true);
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (_) { if (mounted) setState(() => error = '탈퇴 처리를 확인하지 못했습니다.'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('내 프로필')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      if (error != null) Text(error!),
      if (profile == null && error == null) const Center(child: CircularProgressIndicator()),
      if (profile == null && error != null) TextButton(onPressed: load, child: const Text('다시 시도')),
      if (profile != null) ...[
        Text('아이디  ${profile!['id']}'),
        TextField(controller: name, enabled: !busy, maxLength: 30, decoration: const InputDecoration(labelText: '이름')),
        TextField(controller: birth, enabled: !busy, decoration: const InputDecoration(labelText: '생년월일 (YYYY-MM-DD)')),
        DropdownButton<String>(value: gender, hint: const Text('성별'), items: const [
          DropdownMenuItem(value: 'male', child: Text('남성')), DropdownMenuItem(value: 'female', child: Text('여성'))],
          onChanged: busy ? null : (v) => setState(() => gender = v)),
        FilledButton(onPressed: busy ? null : save, child: const Text('저장')),
        TextButton(onPressed: busy ? null : withdraw, child: const Text('회원 탈퇴'))]
    ]));
}
