import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_client.dart';
import 'services/chat_service.dart';

class ChatMessage {
  final String text;
  final bool isMe;
  final List<String>? suggestedFeelings;

  ChatMessage({required this.text, required this.isMe, this.suggestedFeelings});
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}
 
class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(); // 💡 [추가] 키보드 포커스 제어용

  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String _routineType = 'morning';
  int _sessionId = 0;
  Set<String> _selectedFeelings = {};

  bool _isHistoryLoading = false;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInit) {
      _isInit = true;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        _routineType = args['routine'] ?? 'morning';
        _sessionId = int.tryParse(args['session_id']?.toString() ?? '0') ?? 0;
      }

      if (_sessionId != 0) {
        _fetchChatHistory();
      } else {
        _setInitialGreeting();
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose(); // 💡 [추가] 메모리 누수 방지
    super.dispose();
  }

  Future<void> _fetchChatHistory() async {
    setState(() => _isHistoryLoading = true);
    try {
      final historyList = await chatService.getHistory(_sessionId);

      if (!mounted) return;
      setState(() {
        _messages = historyList.map((msg) {
          String msgText =
              msg['text'] ?? msg['content'] ?? msg['message'] ?? '';
          bool isMe = false;
          if (msg.containsKey('is_me')) {
            isMe = msg['is_me'] == true;
          } else if (msg.containsKey('role')) {
            isMe = msg['role'] == 'user';
          }
          return ChatMessage(text: msgText, isMe: isMe);
        }).toList();
        _isHistoryLoading = false;
      });

      if (_messages.isEmpty) {
        _setInitialGreeting();
      } else {
        _scrollToBottom();
      }
    } catch (e) {
      _setInitialGreeting();
      setState(() => _isHistoryLoading = false);
    }
  }

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

  Future<void> _sendMessage() async {
    // 💡 [개선 1] 연타 방지: 이미 로딩 중이면 함수를 멈춤
    if (_isTyping) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isMe: true));
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      final String? userId = prefs.getString('user_id');

      if (token == null) {
        setState(() => _isTyping = false);
        return;
      }

      if (_sessionId == 0) {
        try {
          _sessionId = await chatService.createSession(
            _routineType == 'morning' ? 'Morning' : 'Night',
            userId,
          );
        } on ApiException {
          // 💡 방 생성 실패(서버 응답 오류) 시 에러 던지기
          throw Exception("CreateRoomFailed");
        }
      }

      final data = await chatService.sendMessage(_sessionId, text);

      if (!mounted) return;
      setState(() {
        _isTyping = false;
        final analysisData = data['analysis'] ?? {};
        final aiReply = analysisData['ai_reply'] ?? "이야기를 더 들려주세요.";
        final feelings =
            List<String>.from(analysisData['suggested_feelings'] ?? []);

        _messages.add(ChatMessage(text: aiReply, isMe: false));

        if (feelings.isNotEmpty) {
          _messages.add(ChatMessage(
            text: "이 꿈에서 가장 가까운 느낌을 선택해주세요.",
            isMe: false,
            suggestedFeelings: feelings,
          ));
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTyping = false);

      // 💡 [개선 3] 에러 종류에 따라 다르게 대처
      if (e.toString().contains("CreateRoomFailed")) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('채팅방을 생성하지 못했습니다. 다시 전송해주세요.')));
      } else {
        _loadMockAnalyzeResponse();
      }
    }
  }

  void _loadMockAnalyzeResponse() {
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _messages.add(ChatMessage(
          text: "서버가 응답하지 않아 임시 답변을 띄웁니다.",
          isMe: false,
          suggestedFeelings: ['불안', '긴장', '혼란', '설명하기 어려움'],
        ));
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  Future<void> _submitFeelingsAndGenerate() async {
    if (_selectedFeelings.isEmpty) return;

    setState(() => _isTyping = true);

    try {
      await chatService.generateDiary(_sessionId, _selectedFeelings.toList());
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dream_list');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isTyping = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일기 생성 실패: ${e.statusCode}')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTyping = false);
    }
  }

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
            Expanded(
              child: _isHistoryLoading
                  ? Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF8F6CFF)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _buildChatBubble(msg);
                      },
                    ),
            ),
            if (_isTyping)
              Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(color: Color(0xFF8F6CFF))),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

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
          color: isMe ? Color(0xFF7247FF) : Color(0xFF454048),
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
            Text(message.text,
                style:
                    TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
            if (message.suggestedFeelings != null &&
                message.suggestedFeelings!.isNotEmpty) ...[
              SizedBox(height: 16),
              ...message.suggestedFeelings!
                  .map((feeling) => _buildFeelingCheckbox(feeling))
                  .toList(),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    // 💡 [개선 2] 비어있던 '더 대화하기' 버튼에 입력창 포커스 기능 연결!
                    onPressed: () {
                      _focusNode.requestFocus();
                    },
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey)),
                    child: Text('더 대화하기',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitFeelingsAndGenerate,
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
                  borderRadius: BorderRadius.circular(36)),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode, // 💡 추가된 포커스 노드 연결
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '메시지 입력',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
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
