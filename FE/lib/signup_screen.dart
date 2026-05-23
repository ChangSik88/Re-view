import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // 💡 1. 텍스트 입력창 컨트롤러
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();

  // 💡 2. 성별 상태 저장 변수 (초기값 없음)
  String? _selectedGender;

  // 💡 3. 생년월일 달력 띄우기 함수 (YYYY-MM-DD 포맷 강제)
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        // 백엔드가 원하는 YYYY-MM-DD 형태로 조립
        _birthController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // 💡 4. 회원가입 API 연동 함수
  Future<void> _signUp() async {
    final String name = _nameController.text;
    final String userId = _idController.text;
    final String password = _passwordController.text;
    final String birth = _birthController.text;

    // 빈 칸 검사
    if (name.isEmpty ||
        userId.isEmpty ||
        password.isEmpty ||
        birth.isEmpty ||
        _selectedGender == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('모든 항목을 입력하고 성별을 선택해주세요.')));
      return;
    }

    try {
      // 🚨 주의: 에뮬레이터 로컬 백엔드 주소 (필요시 수정)
      final url =
          Uri.parse('http://13.209.97.107:8000/users/signup'); // 정확한 주소 확인!

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},

        // 💡 수정된 부분: 백엔드 UserCreateBody 스키마와 완벽 일치시켰습니다.
        body: jsonEncode({
          'id': userId, // username -> id 로 수정
          'password': password, // 그대로 유지
          'name': name, // 누락됐던 이름 추가
          'birth': birth, // 누락됐던 생일 추가 (형식 주의: "YYYY-MM-DD")
          'gender': _selectedGender // 누락됐던 성별 추가 ("male" 또는 "female")
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('회원가입 완료! 로그인해주세요.')));
        // 가입 성공 시 이전 화면(로그인 화면)으로 돌아가기
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('회원가입 실패: ${response.statusCode}')));
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
      resizeToAvoidBottomInset: true, // 키보드 올라올 때 화면 찌그러짐 방지
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context), // 뒤로가기 버튼
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: 393,
          height: 852,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 20, // AppBar 영역 고려하여 top 조정
                child: Container(
                  width: 393,
                  height: 750,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Stack(
                    children: [
                      // --- 배경 그라데이션 ---
                      Container(
                        width: 367,
                        height: 178,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Color(0x33DAB2FF), Color(0x33FDA5D5)]),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      Container(
                        width: 367,
                        height: 178,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Color(0x338EC5FF), Color(0x33DAB2FF)]),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      // --- 메인 회원가입 박스 ---
                      Positioned(
                        left: 20,
                        top: 10,
                        child: Container(
                          width: 353,
                          padding: const EdgeInsets.all(28),
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
                              Text('Sign Up',
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 20),

                              // 💡 이름 입력
                              _buildInputField('이름', 'Enter your name',
                                  _nameController, false),

                              // 💡 아이디 입력
                              _buildInputField('아이디', 'Enter your email',
                                  _idController, false),

                              // 💡 비밀번호 입력
                              _buildInputField('비밀번호', 'Enter your password',
                                  _passwordController, true),

                              // 💡 생년월일 입력 (달력 연동)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('생년월일',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 5),
                                  GestureDetector(
                                    onTap: () => _selectDate(context),
                                    child: AbsorbPointer(
                                      // 키보드가 안 올라오게 막음
                                      child: Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.grey
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6.75),
                                        ),
                                        child: TextField(
                                          controller: _birthController,
                                          decoration: InputDecoration(
                                            hintText: 'YYYY-MM-DD',
                                            hintStyle: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 10),
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 14),
                                ],
                              ),

                              // 💡 성별 선택 (체크박스/라디오버튼화)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('성별',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 5),
                                  Row(
                                    children: [
                                      // 남성 버튼
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(
                                              () => _selectedGender = 'male'),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 8),
                                            decoration: BoxDecoration(
                                              color: _selectedGender == 'male'
                                                  ? Colors.blue
                                                      .withValues(alpha: 0.1)
                                                  : Colors.grey
                                                      .withValues(alpha: 0.1),
                                              border: Border.all(
                                                  color:
                                                      _selectedGender == 'male'
                                                          ? Colors.blue
                                                          : Colors.transparent),
                                              borderRadius:
                                                  BorderRadius.circular(6.75),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                    _selectedGender == 'male'
                                                        ? Icons
                                                            .radio_button_checked
                                                        : Icons
                                                            .radio_button_unchecked,
                                                    size: 16,
                                                    color: _selectedGender ==
                                                            'male'
                                                        ? Colors.blue
                                                        : Colors.grey),
                                                SizedBox(width: 5),
                                                Text('남성',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      // 여성 버튼
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(
                                              () => _selectedGender = 'female'),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 8),
                                            decoration: BoxDecoration(
                                              color: _selectedGender == 'female'
                                                  ? Colors.pink
                                                      .withValues(alpha: 0.1)
                                                  : Colors.grey
                                                      .withValues(alpha: 0.1),
                                              border: Border.all(
                                                  color: _selectedGender ==
                                                          'female'
                                                      ? Colors.pink
                                                      : Colors.transparent),
                                              borderRadius:
                                                  BorderRadius.circular(6.75),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                    _selectedGender == 'female'
                                                        ? Icons
                                                            .radio_button_checked
                                                        : Icons
                                                            .radio_button_unchecked,
                                                    size: 16,
                                                    color: _selectedGender ==
                                                            'female'
                                                        ? Colors.pink
                                                        : Colors.grey),
                                                SizedBox(width: 5),
                                                Text('여성',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 25),
                                ],
                              ),

                              // 💡 회원가입 완료 버튼
                              GestureDetector(
                                onTap: _signUp,
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
                                    child: Text('회원가입',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
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
            ],
          ),
        ),
      ),
    );
  }

  // 중복되는 텍스트 필드를 깔끔하게 그려주는 도우미 함수
  Widget _buildInputField(String label, String hint,
      TextEditingController controller, bool isPassword) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6.75),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(height: 14),
      ],
    );
  }
}
