import '../config/api.dart';
import 'api_client.dart';

/// 스토어 아이템 목록/상세 (store API).
class StoreService {
  /// 카테고리별로 묶인 아이템 목록(result 맵)을 반환한다.
  Future<Map<String, dynamic>> getItems() async {
    final data = await apiClient.get(Api.itemList);
    return (data['result'] as Map<String, dynamic>?) ?? {};
  }

  /// 아이템 상세(result 맵)를 반환한다. 없으면 null.
  Future<Map<String, dynamic>?> getItemDetail(int itemId) async {
    final data = await apiClient.get(Api.itemDetail(itemId));
    return data['result'] as Map<String, dynamic>?;
  }
}

final storeService = StoreService();
