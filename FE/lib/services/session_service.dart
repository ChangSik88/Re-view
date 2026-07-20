import '../config/api.dart';
import 'api_client.dart';

/// 꿈 세션 목록/상세 조회 (chatSessionApi).
class SessionService {
  /// 유저의 전체 세션 목록(result 리스트)을 반환한다.
  Future<List<dynamic>> getAllSessions(String? userId) async {
    final data = await apiClient.get('${Api.allSessions}?user_id=$userId');
    return (data['result'] as List<dynamic>?) ?? [];
  }

  /// 단일 세션 상세(result 맵)를 반환한다. 없으면 null.
  Future<Map<String, dynamic>?> getSession(int roomId) async {
    final data = await apiClient.get(Api.singleSession(roomId));
    return data['result'] as Map<String, dynamic>?;
  }
}

final sessionService = SessionService();
