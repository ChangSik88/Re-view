import '../config/api.dart';
import 'api_client.dart';

/// 감정 통계 리포트 조회/생성 (report API).
class ReportService {
  /// 최신 리포트(result 맵)를 반환한다. 없으면 null.
  Future<Map<String, dynamic>?> getReport() async {
    final data = await apiClient.get(Api.report);
    return data['result'] as Map<String, dynamic>?;
  }

  /// 최근 꿈을 분석해 리포트를 새로 생성한다.
  Future<void> generateReport() async {
    await apiClient.post(Api.reportAnalyze);
  }
}

final reportService = ReportService();
