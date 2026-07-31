import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api.dart';

/// 2xx가 아닌 응답일 때 던지는 예외. 화면은 이걸 잡아 폴백/스낵바를 처리한다.
class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// HTTP 통신을 한 곳에 모은 얇은 래퍼.
/// - baseUrl 결합, JWT 토큰 헤더 자동 주입
/// - 응답을 utf8 → JSON으로 디코드
/// - 실패(2xx 아님)는 ApiException으로 통일
class ApiClient {
  Future<Map<String, String>> _headers({required bool auth}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {bool auth = true}) async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}$path'),
      headers: await _headers(auth: auth),
    );
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) async {
    final res = await http.post(
      Uri.parse('${Api.baseUrl}$path'),
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) async {
    final res = await http.patch(
      Uri.parse('${Api.baseUrl}$path'),
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final res = await http.delete(
      Uri.parse('${Api.baseUrl}$path'),
      headers: await _headers(auth: auth),
    );
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw ApiException(res.statusCode, utf8.decode(res.bodyBytes));
  }
}

/// 앱 전역에서 공유하는 단일 인스턴스.
final apiClient = ApiClient();
