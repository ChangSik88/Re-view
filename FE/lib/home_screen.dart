import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // 하단 네비게이션 바 현재 탭 인덱스

  // 💡 하단 네비게이션 바 클릭 시 실행되는 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      // 'AI-채팅' 탭을 누르면 채팅방으로 이동
      Navigator.pushNamed(context, '/dream_list');
    } else if (index == 2 || index == 3) {
      // 스토어, 설정 탭은 껍데기만!
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('아직 준비 중인 기능입니다! 🚀')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 💡 SafeArea: 가짜 배터리 아이콘 대신 OS의 상태표시줄을 피해서 안전한 영역에만 화면을 그립니다.
      body: SafeArea(
        child: Stack(
          children: [
            // --- 상단 헤더 ---
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 393,
                height: 56,
                alignment: Alignment.center,
                child: Text('AI-Diary',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            ),

            // --- 메인 콘텐츠 영역 ---
            Positioned(
              left: 0,
              top: 56, // 헤더 아래부터 시작
              child: Container(
                width: 393,
                height: 652,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Stack(
                  children: [
                    // 배경 그라데이션 박스
                    Container(
                      width: 367,
                      height: 178,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0x33DAB2FF), Color(0x33FDA5D5)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Container(
                      width: 367,
                      height: 178,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0x338EC5FF), Color(0x33DAB2FF)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),

                    // 텍스트 영역
                    Positioned(
                      left: 13,
                      top: 40,
                      child: Text('지금 시작하세요',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    Positioned(
                      left: 13,
                      top: 74,
                      child: Text('당신의 꿈 이야기를 말해보세요',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),

                    // 💡 [핵심] '오늘 일 기록하기' 버튼
                    Positioned(
                      left: 101,
                      top: 129,
                      child: GestureDetector(
                        onTap: () {
                          // 버튼 클릭 시 채팅 화면으로 이동!
                          Navigator.pushNamed(context, '/dream_list');
                        },
                        child: Container(
                          width: 192,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Color(0xB2E900FF), Color(0xE5FC61FF)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('오늘 일 기록하기',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),

                    // --- 하단 가짜 상품 UI 영역 (터치해도 아무 반응 없음) ---
                    Positioned(
                      left: 13,
                      top: 269,
                      child: Text('상품',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    Positioned(
                      left: 18,
                      top: 310,
                      child: Row(
                        children: [
                          _buildFakeTab('다이어리', true),
                          SizedBox(width: 12),
                          _buildFakeTab('악세서리', false),
                          SizedBox(width: 12),
                          _buildFakeTab('기타', false),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 375,
                      child: Container(
                        width: 149,
                        height: 181,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(12.75),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('드림 다이어리',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('8,990원', style: TextStyle(fontSize: 10)),
                            SizedBox(height: 10),
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

      // 💡 [핵심] 하단 가짜 바 대신, Flutter 공식 BottomNavigationBar 적용
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // 탭이 4개 이상일 때 밀림 방지
        selectedItemColor: Color(0xFF4589FE),
        unselectedItemColor: Colors.black,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈 화면'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: 'AI-채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: '스토어'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }

  // 가짜 탭(다이어리, 악세서리 등) 그려주는 헬퍼 함수
  Widget _buildFakeTab(String title, bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isActive ? Color(0xFF030213) : Color(0xFFECEEF2),
        borderRadius: BorderRadius.circular(6.75),
      ),
      child: Text(title,
          style: TextStyle(
              color: isActive ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold)),
    );
  }
}
