/// 채팅 화면의 말풍선 하나를 나타내는 모델.
class ChatMessage {
  final String text;
  final bool isMe;
  final List<String>? suggestedFeelings;

  ChatMessage({
    required this.text,
    required this.isMe,
    this.suggestedFeelings,
  });
}
