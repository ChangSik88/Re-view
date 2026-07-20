import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();

  String? _selectedGender;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _birthController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _signUp() async {
    final String name = _nameController.text;
    final String userId = _idController.text;
    final String password = _passwordController.text;
    final String birth = _birthController.text;

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
      await authService.signup(
        id: userId,
        password: password,
        name: name,
        birth: birth,
        gender: _selectedGender!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('회원가입 완료! 로그인해주세요.')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 실패: ${e.statusCode}')));
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // AppBar 뒤로 배경이 스며들게 설정 (그라데이션 자연스럽게)
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // --- 배경 그라데이션 장식 ---
          Positioned(
            top: -50,
            left: -20,
            right: -20,
            child: Container(
              height: 300,
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
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0x338EC5FF), Color(0x33DAB2FF)]),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),

          // --- 메인 회원가입 폼 영역 ---
          SafeArea(
            child: SingleChildScrollView(
              // 💡 키보드 올라와도 안전하게 스크롤
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
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
                    Text('Sign Up',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold)),
                    SizedBox(height: 30),

                    _buildInputField(
                        '이름', 'Enter your name', _nameController, false),
                    _buildInputField(
                        '아이디', 'Enter your email', _idController, false),
                    _buildInputField('비밀번호', 'Enter your password',
                        _passwordController, true),

                    // 생년월일 입력
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('생년월일',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(height: 5),
                        GestureDetector(
                          onTap: () => _selectDate(context),
                          child: AbsorbPointer(
                            child: Container(
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6.75),
                              ),
                              child: TextField(
                                controller: _birthController,
                                decoration: InputDecoration(
                                  hintText: 'YYYY-MM-DD',
                                  hintStyle: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 12),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 14),
                      ],
                    ),

                    // 성별 선택
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('성별',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(height: 5),
                        Row(
                          children: [
                            // 남성 버튼
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedGender = 'male'),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedGender == 'male'
                                        ? Colors.blue.withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    border: Border.all(
                                        color: _selectedGender == 'male'
                                            ? Colors.blue
                                            : Colors.transparent),
                                    borderRadius: BorderRadius.circular(6.75),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          _selectedGender == 'male'
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          size: 16,
                                          color: _selectedGender == 'male'
                                              ? Colors.blue
                                              : Colors.grey),
                                      SizedBox(width: 5),
                                      Text('남성',
                                          style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            // 여성 버튼
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedGender = 'female'),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedGender == 'female'
                                        ? Colors.pink.withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    border: Border.all(
                                        color: _selectedGender == 'female'
                                            ? Colors.pink
                                            : Colors.transparent),
                                    borderRadius: BorderRadius.circular(6.75),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          _selectedGender == 'female'
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          size: 16,
                                          color: _selectedGender == 'female'
                                              ? Colors.pink
                                              : Colors.grey),
                                      SizedBox(width: 5),
                                      Text('여성',
                                          style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 30),
                      ],
                    ),

                    // 회원가입 완료 버튼
                    GestureDetector(
                      onTap: _signUp,
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
          ),
        ],
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
          height: 45,
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
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(height: 14),
      ],
    );
  }
}
