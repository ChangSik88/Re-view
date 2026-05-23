import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 채팅 메시지를 담을 클래스 (데이터 스키마)
class ChatMessage {
  final String text;
  final bool isMe; // 내가 보낸 건지, AI가 보낸 건지 구분
  final List<String>? suggestedFeelings; // AI가 감정 분석을 줬을 때 띄워줄 체크박스 데이터

  ChatMessage({required this.text, required this.isMe, this.suggestedFeelings});
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String _routineType = 'morning';

  // 💡 추가된 부분: 방 번호를 저장할 변수
  int _sessionId = 0;
  Set<String> _selectedFeelings = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _routineType = args['routine'] ?? 'morning';
      // 💡 추가된 부분: 이전 화면에서 넘겨준 session_id를 꽉 잡습니다!
      _sessionId = args['session_id'] ?? 0;
    }

    if (_messages.isEmpty) {
      _setInitialGreeting();
    }
  }

  // 💡 모닝/굿나잇 분기 처리 (기획 내용 완벽 반영!)
  void _setInitialGreeting() {
    if (_routineType == 'morning') {
      _messages.add(ChatMessage(text: "모닝 루틴을 작성해 볼까요?", isMe: false));
      _messages.add(ChatMessage(text: "오늘 꾼 꿈을 말해주세요!", isMe: false));
    } else {
      _messages.add(ChatMessage(text: "오늘 하루도 수고하셨어요!", isMe: false));
      _messages
          .add(ChatMessage(text: "오늘은 어떤 일이 있었나요?\n같이 얘기해봐요!", isMe: false));
    }
    setState(() {});
  }

// 💡 1. 사용자가 텍스트를 전송했을 때
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isMe: true));
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // 🚀 토큰 꺼내기
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      final url = Uri.parse('http://13.209.97.107:8000/chatting/message');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // 🚀 401, 422 방어용 토큰!
        },
        body: jsonEncode({
          "session_id": _sessionId, // 🚀 백엔드에 방 번호 전달
          "message": text
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 인코딩 깨짐 방지 처리
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        setState(() {
          _isTyping = false;

          // 🚀 핵심 수정 1: 'analysis'라는 중간 상자를 먼저 엽니다!
          final analysisData = data['analysis'] ?? {};

          // 🚀 핵심 수정 2: 중간 상자 안에서 진짜 알맹이들을 꺼냅니다!
          final aiReply = analysisData['ai_reply'] ?? "이야기를 더 들려주세요.";
          final feelings =
              List<String>.from(analysisData['suggested_feelings'] ?? []);

          // 💡 AI 답변 말풍선을 먼저 띄웁니다!
          _messages.add(ChatMessage(text: aiReply, isMe: false));

          // 💡 키워드가 있으면 체크박스 말풍선을 이어서 띄웁니다!
          if (feelings.isNotEmpty) {
            _messages.add(ChatMessage(
              text: "이 꿈에서 가장 가까운 느낌을 선택해주세요.",
              isMe: false,
              suggestedFeelings: feelings,
            ));
          }
        });
        _scrollToBottom();
      } else {
        _loadMockAnalyzeResponse();
      }
    } catch (e) {
      _loadMockAnalyzeResponse();
    }
  }

  // 해커톤 시연용 가짜 응답 (API 서버 연결 안 될 때 작동)
  void _loadMockAnalyzeResponse() {
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _messages.add(ChatMessage(
          text: "이 꿈에서 가장 가까운 느낌이 무엇이었나요?",
          isMe: false,
          suggestedFeelings: ['불안', '긴장', '혼란', '설명하기 어려움'], // 체크박스로 뜰 녀석들
        ));
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  // 💡 2. 감정 체크박스 선택 후 "일기 작성" 버튼 눌렀을 때 (두 번째 API 호출)
  Future<void> _submitFeelingsAndGenerate() async {
    if (_selectedFeelings.isEmpty) return;

    setState(() {
      _isTyping = true;
    });

    try {
      // 🚀 토큰 꺼내기
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      final url = Uri.parse('http://13.209.97.107:8000/chatting/diary');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // 🚀 토큰 필수!
        },
        body: jsonEncode({
          "session_id": _sessionId, // 🚀 어떤 채팅방의 일기를 쓸지 알려줌
          "selected_feelings": _selectedFeelings.toList(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 일기 생성 성공 시 리스트 화면으로 이동
        Navigator.pushReplacementNamed(context, '/dream_list');
      } else {
        // 실패 시 에러 스낵바
        setState(() {
          _isTyping = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('일기 생성 실패: ${response.statusCode}')));
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
      });
      print("일기 생성 에러: $e");
    }
  }

  // 스크롤을 맨 아래로 내려주는 함수
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1B21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 💡 [채팅 로그 영역]
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildChatBubble(msg);
                },
              ),
            ),

            // AI 로딩 인디케이터
            if (_isTyping)
              Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(color: Color(0xFF8F6CFF))),

            // 💡 [입력창 영역] (무진님 코드 UI 반영)
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // 말풍선 그리는 함수
  Widget _buildChatBubble(ChatMessage message) {
    bool isMe = message.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color:
              isMe ? Color(0xFF7247FF) : Color(0xFF454048), // 나는 보라색, AI는 짙은 회색
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 일반 텍스트
            Text(message.text,
                style:
                    TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),

            // 💡 AI가 감정 분석(체크박스)을 보냈을 때만 렌더링되는 마법의 UI
            if (message.suggestedFeelings != null &&
                message.suggestedFeelings!.isNotEmpty) ...[
              SizedBox(height: 16),
              ...message.suggestedFeelings!
                  .map((feeling) => _buildFeelingCheckbox(feeling))
                  .toList(),
              SizedBox(height: 16),

              // 하단 버튼 2개 (일기 작성 등)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey)),
                    child: Text('더 대화하기',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitFeelingsAndGenerate, // 💡 최종 제출 버튼
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.white),
                    child: Text('일기 작성',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  )
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  // 체크박스 UI (단순 터치 로직 구현)
  Widget _buildFeelingCheckbox(String feeling) {
    bool isSelected = _selectedFeelings.contains(feeling);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedFeelings.remove(feeling);
          } else {
            _selectedFeelings.add(feeling);
          }
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              color: isSelected ? Color(0xFF8F6CFF) : Colors.grey,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(feeling, style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // 맨 밑 입력창 UI
  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Color(0xFF1F1C21)),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline, color: Colors.grey),
          SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Color(0xFF100D10),
                borderRadius: BorderRadius.circular(36),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '메시지 입력',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) => _sendMessage(), // 엔터 쳐도 전송
              ),
            ),
          ),
          SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage, // 💡 전송 버튼 누르면 API 호출!
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Color(0xFF7247FF), shape: BoxShape.circle),
              child: Icon(Icons.send, color: Colors.white, size: 20),
            ),
          )
        ],
      ),
    );
  }
}
