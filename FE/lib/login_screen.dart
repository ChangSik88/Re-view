import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 💡 1. 사용자가 입력한 아이디와 비밀번호를 담아둘 컨트롤러입니다.
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 💡 2. 로그인 버튼을 눌렀을 때 실행될 백엔드 통신 함수입니다.
  Future<void> _login() async {
    final String userId = _idController.text;
    final String password = _passwordController.text;

    if (userId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')));
      return;
    }

    try {
      final url = Uri.parse('http://13.209.97.107:8000/users/login');

      final response = await http.post(
        url,
        // 💡 1. 백엔드가 JSON을 원하므로 헤더를 다시 추가합니다!
        headers: {'Content-Type': 'application/json'},

        // 💡 2. jsonEncode를 다시 씌우고, 백엔드 변수명인 'userAccount'로 정확히 꽂아줍니다!
        body: jsonEncode({
          'userAccount': userId,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];

        // 💡 사용자가 입력창에 친 아이디를 그대로 가져옵니다.
        final userId = _idController.text;

        print("로그인 성공! 토큰: $token");

        // 🚀 1. 기기 메모리(금고)에 토큰과 아이디 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('user_id', userId); // 다른 API에서 쓰기 위해 아이디도 저장!

        // 🚀 2. 스낵바 알림 띄우기
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('로그인 성공!')));

        // 🚀 3. 저장이 다 끝난 후, 안전하게 홈 화면으로 이동!
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('로그인 실패: ${response.statusCode}')));
      }
    } catch (e) {
      print("에러 발생: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('서버와 연결할 수 없습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 💡 키보드가 올라올 때 화면이 찌그러지는 것을 방지합니다.
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Container(
          width: 393,
          height: 852,
          child: Stack(
            children: [
              // --- (상단 배경 그래픽 및 Header 부분 생략 없이 그대로 유지) ---
              // ... 무진님이 주신 코드의 상단 그래픽 및 헤더 부분 ...
              Positioned(
                left: 0,
                top: 110,
                child: Container(
                  width: 393,
                  height: 652,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Stack(
                    children: [
                      // ... 그라데이션 배경 Container들 유지 ...
                      // 본격적인 흰색 로그인 박스
                      Positioned(
                        left: 20,
                        top: 10,
                        child: Container(
                          width: 353,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 20),
                          decoration: ShapeDecoration(
                            color: Colors.white.withValues(alpha: 0.90),
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
                              // 로고 및 환영 텍스트
                              Text('Welcome Back',
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 10),
                              Text('Sign in to continue to AI-Diary',
                                  style: TextStyle(color: Colors.grey)),
                              SizedBox(height: 30),

                              // 💡 3. 가짜 글씨를 '진짜 입력창(TextField)'으로 교체했습니다.
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('아이디',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 5),
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6.75),
                                    ),
                                    child: TextField(
                                      controller: _idController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter your ID',
                                        hintStyle: TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 10),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 15),

                              // 비밀번호 입력창
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('비밀번호',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 5),
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6.75),
                                    ),
                                    child: TextField(
                                      controller: _passwordController,
                                      obscureText: true, // 💡 비밀번호를 *** 처리합니다.
                                      decoration: InputDecoration(
                                        hintText: 'Enter your password',
                                        hintStyle: TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 10),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30),

                              // 💡 4. 가짜 버튼을 '진짜 클릭되는 버튼'으로 교체하고 API 연동 함수(_login)를 달았습니다.
                              GestureDetector(
                                onTap: _login, // 클릭 시 서버로 데이터 전송!
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: ShapeDecoration(
                                    gradient: LinearGradient(colors: [
                                      Color(0xFFAD46FF),
                                      Color(0xFFF6339A)
                                    ]),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(6.75)),
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

                              // 기타 UI들 (구글 로그인, 회원가입 등)
                              Text('Or continue with',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  // 💡 클릭 시 회원가입 화면으로 이동합니다!
                                  // (주의: main.dart의 routes 부분에 '/signup'이 미리 등록되어 있어야 합니다)
                                  Navigator.pushNamed(context, '/signup');
                                },
                                child: Text('회원가입',
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
