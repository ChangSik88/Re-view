import 'package:flutter/material.dart';
import '../../services/session_service.dart';

class DreamDetailScreen extends StatefulWidget {
  @override
  _DreamDetailScreenState createState() => _DreamDetailScreenState();
}

class _DreamDetailScreenState extends State<DreamDetailScreen> {
  Map<String, dynamic>? _dreamData;
  bool _isLoading = true;
  int? _currentRoomId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final roomId = ModalRoute.of(context)?.settings.arguments as int?;
    if (roomId != null) {
      _currentRoomId = roomId;
      _fetchDreamDetail(roomId);
    } else {
      _loadMockData();
    }
  }

  Future<void> _fetchDreamDetail(int roomId) async {
    try {
      final result = await sessionService.getSession(roomId);
      if (!mounted) return;
      setState(() {
        _dreamData = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
        "title": "로딩 실패 (가짜 데이터)",
        "content": "데이터를 불러오지 못했습니다.",
        "updated_at": "2026-05-19T12:50:51.077Z",
        "image_url": "https://placehold.co/400x300/151216/FFFFFF/png?text=Image"
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100D10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('꿈 상세 기록',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildDetailContent(),

      // 💡 우측 하단 둥근 + 버튼 (기존 채팅방 이어서 하기)
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF454048),
        onPressed: () {
          Navigator.pushNamed(context, '/chat_input', arguments: {
            'session_id': _currentRoomId,
            'routine': _dreamData?['routine_type'] ?? 'morning'
          });
        },
        child: Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
    );
  }

  // 💡 [UI 수정] 배경 전체 이미지를 없애고, 상단 썸네일 박스로 변경!
  Widget _buildDetailContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 상단 썸네일 이미지 박스 (통계 UI와 비슷한 둥근 박스)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(_dreamData?['image_url'] ??
                      "https://placehold.co/400x300"),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: Colors.white10),
              ),
            ),
          ),

          // 2. 하단 텍스트 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(_dreamData?['updated_at'] ?? ''),
                  style: TextStyle(color: Color(0xFFBBB8BD), fontSize: 14),
                ),
                SizedBox(height: 12),
                Text(
                  _dreamData?['title'] ?? '제목 없음',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 24),
                Text(
                  _dreamData?['content'] ?? '',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 16, height: 1.8),
                ),
                SizedBox(height: 100), // 스크롤 여백
              ],
            ),
          ),
        ],
      ),
    );
  }
}
