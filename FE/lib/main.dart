// 💡 메모장에 미리 복사해둘 완성형 main.dart 코드
import 'package:flutter/material.dart';
// 💡 이 줄을 맨 위에 추가해 주세요!
import 'login_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'dream_list_screen.dart';
import 'dream_detail_screen.dart';
import 'chat_screen.dart';
import 'store_screen.dart';
import 'store_detail_screen.dart';
import 'routine_select_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI-Diary',
      theme: ThemeData(primarySwatch: Colors.purple),
      // 💡 첫 화면을 로그인 화면으로 지정합니다.
      home: LoginScreen(),
      routes: {
        '/login': (context) => LoginScreen(), // 1. 로그인
        '/signup': (context) => SignUpScreen(), // 2. 회원가입
        '/home': (context) => HomeScreen(), // 3. 홈 화면 (메인)
        '/dream_list': (context) => DreamListScreen(), // 4. 꿈나라 대시보드 리스트
        '/chat_detail': (context) => DreamDetailScreen(), // 5. 꿈 상세 기록 화면
        '/chat_input': (context) => ChatScreen(), // 6. AI 채팅 화면
        '/store': (context) => StoreScreen(), //7. 스토어 메인 화면
        '/store_detail': (context) => StoreDetailScreen(), //8. 스토어 제품 화면
        '/routine_select': (context) => RoutineSelectScreen(),
      },
    );
  }
}

// 💡 여기에 아까 제가 짜드린 _LoginScreenState 포함된 LoginScreen 코드를 통째로 이어 붙여두세요!
