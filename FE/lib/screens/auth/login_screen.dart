import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    final String userId = _idController.text;
    final String password = _passwordController.text;

    if (userId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')));
      return;
    }

    try {
      final token = await authService.login(userId, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token ?? '');
      await prefs.setString('user_id', _idController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('로그인 성공!')));

      Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: ${e.statusCode}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('서버와 연결할 수 없습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      // 💡 Stack은 배경 그래픽을 깔아두는 용도로만 남겨둡니다.
      body: Stack(
        children: [
          // --- 배경 그라데이션 장식 (화면 상단에 고정) ---
          Positioned(
            top: -50,
            left: -20,
            right: -20,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0x33DAB2FF), Color(0x33FDA5D5)]),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          Positioned(
            top: -30,
            left: -10,
            right: -30,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0x338EC5FF), Color(0x33DAB2FF)]),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),

          // --- 메인 로그인 폼 영역 ---
          SafeArea(
            child: Center(
              // 💡 화면 중앙에 박스를 배치합니다.
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Container(
                  width: double.infinity, // 💡 가로 100% 꽉 채우기
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                  decoration: ShapeDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(21)),
                    shadows: [
                      BoxShadow(
                          color: Color(0x3F000000),
                          blurRadius: 50,
                          offset: Offset(0, 25),
                          spreadRadius: -12)
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Welcome Back',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      Text('Sign in to continue to AI-Diary',
                          style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 40),

                      // 아이디 입력
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('아이디',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(height: 5),
                          Container(
                            height: 45, // 터치하기 편하게 높이 살짝 증대
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6.75),
                            ),
                            child: TextField(
                              controller: _idController,
                              decoration: InputDecoration(
                                hintText: 'Enter your ID',
                                hintStyle:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),

                      // 비밀번호 입력
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('비밀번호',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(height: 5),
                          Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6.75),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                hintStyle:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 30),

                      // 로그인 버튼
                      GestureDetector(
                        onTap: _login,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: ShapeDecoration(
                            gradient: LinearGradient(
                                colors: [Color(0xFFAD46FF), Color(0xFFF6339A)]),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.75)),
                          ),
                          child: Center(
                            child: Text(
                              '로그인',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // 회원가입 유도
                      Text('Or continue with',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: Text('회원가입',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
