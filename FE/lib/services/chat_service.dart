import '../config/api.dart';
import 'api_client.dart';

/// 채팅방 생성 / 메시지 전송 / 일기 생성 / 대화 내역 (chatApi).
class ChatService {
  /// 채팅방을 만들고 session_id를 반환한다.
  Future<int> createSession(String routineType, String? userId) async {
    final data = await apiClient.post(
      Api.createSession,
      body: {'routine_type': routineType, 'user_id': userId},
    );
    return (data['session_id'] as int?) ?? 0;
  }

  /// 메시지를 보내고 응답(analysis 등 포함)을 그대로 반환한다.
  Future<Map<String, dynamic>> sendMessage(int sessionId, String message) async {
    final data = await apiClient.post(
      Api.message,
      body: {'session_id': sessionId, 'message': message},
    );
    return data as Map<String, dynamic>;
  }

  /// 선택한 감정 키워드로 일기 생성을 요청한다.
  /// BE의 DiaryRequest는 selected_keywords 필드를 읽는다.
  Future<void> generateDiary(int sessionId, List<String> selectedKeywords) async {
    await apiClient.post(
      Api.diary,
      body: {'session_id': sessionId, 'selected_keywords': selectedKeywords},
    );
  }

  /// 특정 방의 대화 내역(result 리스트)을 반환한다.
  Future<List<dynamic>> getHistory(int roomId) async {
    final data = await apiClient.get(Api.history(roomId));
    if (data is List) return data;
    if (data is Map) {
      return data['result'] ?? data['messages'] ?? data['history'] ?? [];
    }
    return [];
  }
}

final chatService = ChatService();
