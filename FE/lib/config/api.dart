/// API 서버 주소와 엔드포인트 경로를 한 곳에서 관리한다.
///
/// baseUrl은 빌드 시 `--dart-define=API_BASE_URL=http://...`로 덮어쓸 수 있다.
/// (지정하지 않으면 아래 기본값을 사용한다.)
class Api {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://re-view-uxww.onrender.com',
  );

  /// 서버가 localhost 주소를 담아 보내는 경우(로컬 개발)를 대비한 이미지 URL 보정.
  static String imageUrl(String raw) =>
      raw.replaceAll('http://localhost:8000', baseUrl);

  // Auth
  static const String login = '/users/login';
  static const String signup = '/users/signup';

  // Chat (chatApi)
  static const String createSession = '/chatting/session';
  static const String message = '/chatting/message';
  static const String diary = '/chatting/diary';
  static String history(int roomId) => '/chatting/history/$roomId';

  // Session (chatSessionApi — 꿈 목록/상세)
  static const String allSessions = '/chatting/session/all';
  static String singleSession(int roomId) =>
      '/chatting/session/single/$roomId';
  static String sessionMark(int roomId) => '/chatting/session/$roomId/mark';
  static String deleteSession(int roomId) => '/chatting/session/$roomId';

  // Report
  static const String report = '/report';
  static const String reportAnalyze = '/report/analyze';

  // Store
  static const String itemList = '/item/list';
  static String itemDetail(int itemId) => '/item/detail/$itemId';
}
