import '../config/api.dart';
import 'api_client.dart';

/// 꿈 세션 목록/상세 조회, 즐겨찾기 설정, 삭제 (chatSessionApi + chatApi 일부).
class SessionService {
  /// 유저의 전체 세션 목록(result 리스트)을 반환한다.
  /// isMarked가 true면 즐겨찾기한 세션만 필터링해 받아온다.
  Future<List<dynamic>> getAllSessions(String? userId, {bool? isMarked}) async {
    final query = isMarked == null ? '' : '&is_marked=$isMarked';
    final data =
        await apiClient.get('${Api.allSessions}?user_id=$userId$query');
    return (data['result'] as List<dynamic>?) ?? [];
  }

  /// 단일 세션 상세(result 맵)를 반환한다. 없으면 null.
  Future<Map<String, dynamic>?> getSession(int roomId) async {
    final data = await apiClient.get(Api.singleSession(roomId));
    return data['result'] as Map<String, dynamic>?;
  }

  /// 즐겨찾기 상태를 명시적으로 설정하고, 저장된 값을 반환한다.
  Future<bool> setMarked(int roomId, bool isMarked) async {
    final data = await apiClient
        .patch(Api.sessionMark(roomId), body: {'is_marked': isMarked});
    return data['is_marked'] as bool;
  }

  /// 세션(꿈 일기)을 삭제한다.
  Future<void> deleteSession(int roomId) async {
    await apiClient.delete(Api.deleteSession(roomId));
  }
}

final sessionService = SessionService();
