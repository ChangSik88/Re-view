import 'package:flutter/material.dart';

class RoutineSelectScreen extends StatefulWidget {
  @override
  _RoutineSelectScreenState createState() => _RoutineSelectScreenState();
}

class _RoutineSelectScreenState extends State<RoutineSelectScreen> {
  // 🚀 빈 방(0번)으로 조용히 넘기기! (서버에 쓰레기 데이터 생성 안 함)
  void _goToChat(String routineType) {
    Navigator.pushReplacementNamed(context, '/chat_input', arguments: {
      'session_id': 0, // 0은 '아직 서버에 방이 안 만들어졌다'는 비밀 신호입니다.
      'routine': routineType == 'Morning' ? 'morning' : 'night'
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('AI-Chat',
            style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, const Color(0xFF666666)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _goToChat("Morning"), // 🚀 바로 이동!
              child: Container(
                width: 290,
                height: 106,
                decoration: ShapeDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(0.60),
                      const Color(0xFF999999)
                    ],
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Center(
                  child: Text('모닝 루틴 작성하기',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.43)),
                ),
              ),
            ),
            SizedBox(height: 50),
            GestureDetector(
              onTap: () => _goToChat("Night"), // 🚀 바로 이동!
              child: Container(
                width: 290,
                height: 106,
                decoration: ShapeDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(0.60),
                      const Color(0xFF999999)
                    ],
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Center(
                  child: Text('굿나잇 루틴 작성하기',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.43)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
