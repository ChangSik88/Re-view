import '../config/api.dart';
import 'api_client.dart';

/// 로그인 / 회원가입 (users API).
class AuthService {
  /// 성공 시 access_token 문자열을 반환. 인증 실패 등은 ApiException으로 던진다.
  Future<String?> login(String userAccount, String password) async {
    final data = await apiClient.post(
      Api.login,
      auth: false,
      body: {'userAccount': userAccount, 'password': password},
    );
    return data['access_token'] as String?;
  }

  Future<void> signup({
    required String id,
    required String password,
    required String name,
    required String birth,
    required String gender,
  }) async {
    await apiClient.post(
      Api.signup,
      auth: false,
      body: {
        'id': id,
        'password': password,
        'name': name,
        'birth': birth,
        'gender': gender,
      },
    );
  }
}

final authService = AuthService();
