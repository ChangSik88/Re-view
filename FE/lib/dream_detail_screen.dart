import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// 💡 1. 토큰을 꺼내오기 위해 패키지 추가!
import 'package:shared_preferences/shared_preferences.dart';

class DreamDetailScreen extends StatefulWidget {
  @override
  _DreamDetailScreenState createState() => _DreamDetailScreenState();
}

class _DreamDetailScreenState extends State<DreamDetailScreen> {
  Map<String, dynamic>? _dreamData;
  bool _isLoading = true;
  int? _currentRoomId; // 현재 방 ID 저장용

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 리스트 화면이나 채팅 화면에서 넘겨준 room_id 받기
    final roomId = ModalRoute.of(context)?.settings.arguments as int?;
    if (roomId != null) {
      _currentRoomId = roomId;
      _fetchDreamDetail(roomId);
    } else {
      _loadMockData();
    }
  }

// 💡 2. API 호출 시 토큰과 파라미터 적용
  Future<void> _fetchDreamDetail(int roomId) async {
    try {
      // 🚀 금고에서 토큰 꺼내기 (user_id는 백엔드가 토큰에서 알아서 꺼내 쓰므로 생략 가능!)
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      if (token == null) {
        print("토큰이 없습니다. 로그인 화면으로 이동해야 합니다.");
        _loadMockData();
        return;
      }

      // 🚀 수정 1: 물음표(?) 쿼리 대신 슬래시(/)를 써서 백엔드 라우터 규격에 완벽히 맞춥니다.
      final url = Uri.parse(
          'http://13.209.97.107:8000/chatting/session/single/$roomId');

      // 🚀 헤더에 Bearer 토큰 달아서 발사!
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // 💡 한글 깨짐 방지용 utf8 디코딩 추가
        final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));

        setState(() {
          // 🚀 수정 2: 백엔드가 리스트가 아닌 '단일 객체'를 주므로 [0]을 빼고 바로 담습니다!
          _dreamData = decodedResponse['result'];
          _isLoading = false;
        });
      } else {
        print("상세 API 에러: ${response.statusCode}");
        _loadMockData();
      }
    } catch (e) {
      print("통신 에러: $e");
      _loadMockData();
    }
  }

  String _formatDate(String isoString) {
    try {
      DateTime dt = DateTime.parse(isoString).toLocal();
      return '${dt.year}년 ${dt.month}월 ${dt.day}일';
    } catch (e) {
      return '날짜 정보 없음';
    }
  }

  void _loadMockData() {
    setState(() {
      _dreamData = {
        "room_id": _currentRoomId ?? 0,
        "title": "고등학교로 돌아간 꿈",
        "content":
            "체육관에 앉아 있었다. 분명히 고등학교인데 내가 알던 교복 색이 아니었고 주변이 전부 낯설었다.\n\n이름을 부르는 소리가 들렸는데, 내 이름이 맞는 것 같으면서도 확신이 들지 않았다.\n\n앞을 보니까 단상 위에 선생님이 서 있었는데, 얼굴이 흐릿하게 보였다. 마치 일부러 초점을 잃은 것처럼.\n\n그 순간, '여기서 다시 시작해야 한다'는 생각이 들었다. 이미 한 번 지나온 시간인데, 다시 처음으로 돌아온 느낌이었다.",
        "tags": "학교, 낯섦",
        "is_marked": true,
        "updated_at": "2026-05-19T12:50:51.077Z",
        "routine_type": "nightmare",
        "image_url":
            "https://placehold.co/400x800/151216/FFFFFF/png?text=Dream+Background"
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151216),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('AI-Chat',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildDetailContent(),

      // 💡 3. 여기서는 해/달 팝업 대신, 기존 채팅방으로 돌아가는 + 버튼만 띄웁니다!
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF454048),
        onPressed: () {
          // 🚀 + 버튼 누르면 기존 채팅방(session_id) 정보를 들고 채팅창으로 넘어감!
          Navigator.pushNamed(context, '/chat_input', arguments: {
            'session_id': _currentRoomId,
            'routine': _dreamData?['routine_type'] ?? 'morning' // 기존 루틴 타입 유지
          });
        },
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDetailContent() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
                  _dreamData?['image_url'] ?? "https://placehold.co/400x800"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xBF151216),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Text(
                  _formatDate(_dreamData?['updated_at'] ?? ''),
                  style: TextStyle(color: Color(0xFFBBB8BD), fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  _dreamData?['title'] ?? '제목 없음',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 30),
                Text(
                  _dreamData?['content'] ?? '',
                  style:
                      TextStyle(color: Colors.white, fontSize: 16, height: 1.8),
                ),
                SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
