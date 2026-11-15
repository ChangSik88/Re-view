import 'package:geolocator/geolocator.dart';

/// 현재 GPS 좌표를 가져온다. 서비스 꺼짐·권한 거부·시간 초과는 null로 돌려
/// 호출 쪽이 위치 없이 기록을 저장하게 한다.
Future<Position?> currentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(timeLimit: Duration(seconds: 10)));
  } catch (_) {
    return null;
  }
}
