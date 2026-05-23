import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DreamListScreen extends StatefulWidget {
  @override
  _DreamListScreenState createState() => _DreamListScreenState();
}

class _DreamListScreenState extends State<DreamListScreen> {
  List<dynamic> _dreamList = [];
  bool _isLoading = true;

  // 💡 1. 플러스 버튼 상태를 기억하는 변수
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchDreams();
  }

  Future<void> _fetchDreams() async {
    try {
      // 🚀 1. 토큰과 유저 ID를 모두 꺼냅니다.
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      final String? userId = prefs.getString('user_id');

      if (token == null || userId == null) {
        print("토큰 또는 유저 ID가 없습니다. 다시 로그인하세요.");
        return;
      }

      // 🚀 2. 백엔드에서 특정 유저의 세션을 찾을 수 있게 url 끝에 '?user_id=...' 를 붙여줍니다.
      final url = Uri.parse(
          'http://13.209.97.107:8000/chatting/session/all?user_id=$userId');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // 한글 깨짐 방지 (utf8 디코딩)
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // 🚀 3. 백엔드 스키마에 맞게 'result' 상자 안에서 진짜 배열(List)만 꺼냅니다!
        final List<dynamic> sessionList = data['result'] ?? [];

        setState(() {
          _dreamList = sessionList.map((session) {
            String rawDate = session['updated_at'] ?? '';
            String formattedDate =
                rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

            // 🚀 핵심 수정: 백엔드에서 준 진짜 이미지 주소를 먼저 찾습니다!
            String? realImageUrl = session['image_url'];

            // 진짜 주소가 비어있지 않으면 그걸 쓰고, 비어있으면 루틴 타입에 맞춰 임시 배경을 깔아줍니다.
            String displayImageUrl = (realImageUrl != null &&
                    realImageUrl.isNotEmpty)
                ? realImageUrl
                : (session['routine_type'] == 'night'
                    ? "https://placehold.co/400x300/2C2530/FFFFFF/png?text=Night+Dream"
                    : "https://placehold.co/400x300/1F1B21/FFFFFF/png?text=Morning+Dream");

            return {
              "id": session['room_id'],
              "date": formattedDate,
              "title": session['title'] ?? "제목 없는 꿈",
              "content": session['content'] ?? "일기 내용이 없습니다.",

              // 🚀 찾은 이미지 주소를 UI로 넘겨줍니다.
              "image_url": displayImageUrl
            };
          }).toList();

          _isLoading = false;
        });
      } else {
        print("조회 실패 에러 코드: ${response.statusCode}");
        _loadMockData(); // 실패 시 꼼수 데이터 로드
      }
    } catch (e) {
      print("API 호출 에러: $e");
      _loadMockData();
    }
  }

  void _loadMockData() {
    setState(() {
      _dreamList = [
        {
          "id": 1,
          "date": "2026년 4월 13일",
          "title": "고등학교 입학식 날",
          "content": "체육관에 앉아 있었다. 분명히 고등학교인데 내가 알던 교복 색이 아니었고...",
          "image_url":
              "https://placehold.co/400x300/1F1B21/FFFFFF/png?text=Dream+1"
        },
        {
          "id": 2,
          "date": "2026년 4월 11일",
          "title": "지진 난 날 자각몽",
          "content": "자각몽을 꾸는데 꿈에서 자연재해 현상이 벌어지고 있었음. 주위 사람들은 다 도망치는데...",
          "image_url":
              "https://placehold.co/400x300/2C2530/FFFFFF/png?text=Dream+2"
        },
      ];
      _isLoading = false;
    });
  }

  Future<void> _createNewSession(String routineType) async {
    setState(() {
      _isMenuOpen = false;
    });

    // 사용자에게 잠시 기다리라는 로딩 스피너 띄우기
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: Color(0xFF8F6CFF))),
    );

    try {
      // 🚀 1. 메모리(SharedPreferences)에서 저장된 토큰과 유저 아이디를 꺼내옵니다.
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      final String? userId = prefs.getString('user_id');

      // 토큰이 없으면 로딩창을 닫고 경고를 띄운 뒤 중단합니다.
      if (token == null) {
        Navigator.pop(context); // 로딩 팝업 닫기
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('인증 토큰이 없습니다. 다시 로그인해주세요.')));
        return;
      }

      final url = Uri.parse('http://13.209.97.107:8000/chatting/session');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // 🚀 2. 401 에러를 방지하기 위해 인증 헤더를 정확히 수혈해 줍니다!
          'Authorization': 'Bearer $token',
        },
        // 🚀 3. 백엔드 명세에 맞게 routine_type과 user_id를 JSON에 담아 보냅니다.
        body: jsonEncode({
          "routine_type": routineType,
          "user_id": userId, // 로그인 폼에서 입력받아 저장했던 유저 ID 주입!
        }),
      );

      // 로딩 팝업 닫기
      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final int newSessionId = data['session_id'] ?? 0;

        // 대망의 화면 이동! 세션 ID와 루틴 타입을 들고 채팅 화면으로 넘어갑니다.
        Navigator.pushNamed(
          context,
          '/chat_input',
          arguments: {
            'session_id': newSessionId,
            'routine': routineType == 'Morning' ? 'morning' : 'night'
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('채팅방 생성 실패: ${response.statusCode}')));
      }
    } catch (e) {
      Navigator.pop(context); // 에러 나도 로딩 팝업 닫기
      print("세션 생성 에러: $e");

      // 해커톤 시연용 강제 이동 로직 (서버 꺼져있을 때 대비 예비책)
      Navigator.pushNamed(
        context,
        '/chat_input',
        arguments: {
          'session_id': 999,
          'routine': routineType == 'Morning' ? 'morning' : 'night'
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100D10),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('AI-Chat',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('내 꿈나라',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: Color(0xFF1F1B21),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('전체 ${_dreamList.length}개',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                  )
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _dreamList.length,
                      itemBuilder: (context, index) {
                        return _buildDreamCard(_dreamList[index]);
                      },
                    ),
            ),
          ],
        ),
      ),

      // 💡 3. 화면 우측 하단에 해/달 팝업 버튼 배치
      floatingActionButton: _buildExpandableFab(),
    );
  }

  Widget _buildDreamCard(Map<String, dynamic> dream) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/chat_detail', arguments: dream['id']);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image:
                NetworkImage(dream['image_url'] ?? "https://placehold.co/400"),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
            ),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dream['date'] ?? '',
                  style: TextStyle(color: Color(0xFF746E7A), fontSize: 12)),
              SizedBox(height: 4),
              Text(dream['title'] ?? '',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              SizedBox(height: 4),
              Text(dream['content'] ?? '',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // 💡 4. 플러스 버튼 누르면 애니메이션처럼 뜨는 플로팅 액션 버튼 세트
  Widget _buildExpandableFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isMenuOpen) ...[
          // 해(아침) 버튼
          FloatingActionButton(
            heroTag: 'morningBtn',
            backgroundColor: const Color(0xFF454048),
            // 누르면 "Morning" 글자를 들고 API 호출 함수로 달려갑니다!
            onPressed: () => _createNewSession("Morning"),
            child: Icon(Icons.wb_sunny_outlined, color: Colors.white),
          ),
          SizedBox(height: 16),

          // 달(밤) 버튼
          FloatingActionButton(
            heroTag: 'nightBtn',
            backgroundColor: const Color(0xFF454048),
            // 누르면 "Night" 글자를 들고 API 호출 함수로 달려갑니다!
            onPressed: () => _createNewSession("Night"),
            child: Icon(Icons.nightlight_outlined, color: Colors.white),
          ),
          SizedBox(height: 16),
        ],

        // 메인 토글 (+) 버튼
        FloatingActionButton(
          heroTag: 'mainToggleBtn',
          backgroundColor: const Color(0xFF454048),
          onPressed: () {
            setState(() {
              _isMenuOpen = !_isMenuOpen;
            });
          },
          child:
              Icon(_isMenuOpen ? Icons.close : Icons.add, color: Colors.white),
        ),
      ],
    );
  }
}
