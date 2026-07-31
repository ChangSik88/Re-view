import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';
import '../../services/session_service.dart';
import '../../services/report_service.dart';

class DreamListScreen extends StatefulWidget {
  @override
  _DreamListScreenState createState() => _DreamListScreenState();
}

class _DreamListScreenState extends State<DreamListScreen> {
  List<dynamic> _dreamList = [];
  bool _isLoading = true;
  bool _isMenuOpen = false;
  bool _showOnlyMarked = false;

  Map<String, dynamic>? _reportData;
  bool _isReportLoading = true;
  bool _isReportGenerating = false;

  @override
  void initState() {
    super.initState();
    _fetchDreams();
    _fetchReport();
  }

  Future<void> _fetchDreams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('user_id');

      final sessionList = await sessionService.getAllSessions(userId,
          isMarked: _showOnlyMarked ? true : null);

      if (!mounted) return;
      setState(() {
          _dreamList = sessionList.map((session) {
            String rawDate = session['updated_at'] ?? '';
            String formattedDate =
                rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
            String? realImageUrl = session['image_url'];
            String displayImageUrl = (realImageUrl != null &&
                    realImageUrl.isNotEmpty)
                ? realImageUrl.replaceAll(
                    'localhost', '13.209.97.107') // 혹시 모를 로컬호스트 에러 방어
                : (session['routine_type'] == 'night'
                    ? "https://placehold.co/400x300/2C2530/FFFFFF/png?text=Night+Dream"
                    : "https://placehold.co/400x300/1F1B21/FFFFFF/png?text=Morning+Dream");

            return {
              "id": session['room_id'],
              "date": formattedDate,
              "title": session['title'] ?? "제목 없는 꿈",
              "content": session['content'] ?? "일기 내용이 없습니다.",
              "image_url": displayImageUrl,
              "is_marked": session['is_marked'] == true
            };
          }).toList();
          _isLoading = false;
        });
    } catch (e) {
      if (!mounted) return;
      _loadMockData();
    }
  }

  Future<void> _toggleMarked(int index) async {
    final dream = _dreamList[index];
    final bool newValue = !(dream['is_marked'] == true);
    try {
      await sessionService.setMarked(dream['id'], newValue);
      if (!mounted) return;
      setState(() {
        _dreamList[index]['is_marked'] = newValue;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('즐겨찾기 변경에 실패했습니다.')));
    }
  }

  Future<void> _fetchReport() async {
    setState(() => _isReportLoading = true);
    try {
      final result = await reportService.getReport();
      if (!mounted) return;
      setState(() {
        _reportData = result;
        _isReportLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReportLoading = false);
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isReportGenerating = true);
    try {
      await reportService.generateReport();
      await _fetchReport();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('감정 통계가 새롭게 업데이트 되었습니다! 🔮')));
    } on ApiException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('통계 생성에 실패했습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('서버와 통신할 수 없습니다.')));
    } finally {
      if (mounted) setState(() => _isReportGenerating = false);
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
      ];
      _isLoading = false;
    });
  }

  // 🚀 [핵심 수정] 서버 통신 없이 바로 채팅창(0번 방)으로 넘겨버립니다!
  void _createNewSession(String routineType) {
    setState(() => _isMenuOpen = false); // 열려있던 플로팅 버튼 닫기

    // 방금 수정했던 ChatScreen의 로직을 그대로 타게 만들기 위해 session_id: 0 으로 쏴줍니다.
    Navigator.pushNamed(context, '/chat_input', arguments: {
      'session_id': 0,
      'routine': routineType == 'Morning' ? 'morning' : 'night'
    });
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
            // 💡 감정 통계 섹션 렌더링
            _buildEmotionStatisticsArea(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('전체'),
                    selected: !_showOnlyMarked,
                    selectedColor: Color(0xFF8F6CFF),
                    backgroundColor: Color(0xFF1F1B21),
                    labelStyle: TextStyle(color: Colors.white),
                    onSelected: (_) {
                      setState(() => _showOnlyMarked = false);
                      _fetchDreams();
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('즐겨찾기'),
                    selected: _showOnlyMarked,
                    selectedColor: Color(0xFF8F6CFF),
                    backgroundColor: Color(0xFF1F1B21),
                    labelStyle: TextStyle(color: Colors.white),
                    onSelected: (_) {
                      setState(() => _showOnlyMarked = true);
                      _fetchDreams();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF8F6CFF)))
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _dreamList.length,
                      itemBuilder: (context, index) {
                        return _buildDreamCard(_dreamList[index], index);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildExpandableFab(),
    );
  }

  // 💡 전체 텍스트 팝업 띄우기 함수
  void _showFullReportDialog(String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1B21),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Text('나의 감정 통계 ',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              Text('📊', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              content,
              style:
                  TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('닫기',
                  style: TextStyle(
                      color: Color(0xFFAD46FF), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 💡 칸 축소 & 탭(Tap) 이벤트
  Widget _buildEmotionStatisticsArea() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
      child: GestureDetector(
        onTap: () {
          if (_reportData != null && _reportData!['weekly_content'] != null) {
            _showFullReportDialog(_reportData!['weekly_content']);
          }
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2C2530), Color(0xFF1F1B21)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('나의 감정 통계 📊',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    if (_isReportLoading)
                      Center(
                          child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  color: Color(0xFF8F6CFF), strokeWidth: 2)))
                    else if (_reportData == null)
                      Text('아직 분석된 통계가 없습니다.\n우측 하단 버튼을 눌러 최근 꿈을 분석해보세요!',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14, height: 1.5))
                    else
                      Text(
                        _reportData!['weekly_content'] ?? '분석 내용이 없습니다.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14, height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: _isReportGenerating
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Color(0xFFAD46FF), strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: Icon(Icons.refresh_rounded,
                            color: Color(0xFFAD46FF)),
                        onPressed: _generateReport,
                        tooltip: '통계 새로고침',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDreamCard(Map<String, dynamic> dream, int index) {
    final bool isMarked = dream['is_marked'] == true;
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.pushNamed(context, '/chat_detail',
            arguments: dream['id']);
        if (result == true) _fetchDreams();
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
        child: Stack(
          children: [
            Container(
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
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _toggleMarked(index),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMarked ? Icons.favorite : Icons.favorite_border,
                    color: isMarked ? Color(0xFFF6339A) : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isMenuOpen) ...[
          FloatingActionButton(
            heroTag: 'morningBtn',
            backgroundColor: const Color(0xFF454048),
            onPressed: () => _createNewSession("Morning"),
            child: Icon(Icons.wb_sunny_outlined, color: Colors.white),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'nightBtn',
            backgroundColor: const Color(0xFF454048),
            onPressed: () => _createNewSession("Night"),
            child: Icon(Icons.nightlight_outlined, color: Colors.white),
          ),
          SizedBox(height: 16),
        ],
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
