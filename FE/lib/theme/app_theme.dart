import 'package:flutter/material.dart';

/// 앱 색상 토큰. 값의 출처는 docs/design-tokens.md (FE 실제 구현에서 추출).
///
/// 앞으로 새 위젯은 색 리터럴 대신 이 상수를 참조한다.
/// 기존 화면의 하드코딩 색은 점진적으로 이 토큰으로 대체할 예정.
class AppColors {
  // 브랜드 (퍼플·핑크·블루)
  static const primary = Color(0xFF8F6CFF); // 메인 포인트
  static const primaryStrong = Color(0xFF7247FF); // 진한 버튼/강조
  static const violet = Color(0xFFAD46FF); // 그라데이션·강조
  static const violetStore = Color(0xFF8A38F5); // 스토어 포인트
  static const pink = Color(0xFFF6339A); // 그라데이션 끝/핑크 포인트
  static const blue = Color(0xFF4589FE); // 보조 포인트

  // 배경·서피스 (다크)
  static const bg = Color(0xFF100D10); // 가장 어두운 배경
  static const surface = Color(0xFF1F1B21); // 카드/서피스
  static const surface2 = Color(0xFF2C2530); // 한 단계 밝은 서피스
  static const border = Color(0xFF454048); // 구분선/비활성

  // 텍스트·그레이
  static const textMuted = Color(0xFFBBB8BD);
  static const textMuted2 = Color(0xFF746E7A);
  static const grey666 = Color(0xFF666666);
  static const grey999 = Color(0xFF999999);

  // 라이트 톤 (홈·스토어 일부)
  static const ink = Color(0xFF030213);
  static const lightBg = Color(0xFFECEEF2);
  static const lightCard = Color(0xFFF3F4F6);
  static const placeholder = Color(0xFFD9D9D9);

  // 글로우·그림자 (투명도 포함)
  static const glowBlue = Color(0x338EC5FF);
  static const glowViolet = Color(0x33DAB2FF);
  static const glowPink = Color(0x33FDA5D5);
  static const glowMagenta = Color(0xB2E900FF);
  static const glowMagenta2 = Color(0xE5FC61FF);
  static const shadow = Color(0x3F000000);
}

/// 타이포 스케일. size/weight만 정의하고, 색은 사용처에서 copyWith(color:)로 지정한다.
class AppTextStyles {
  static const display = TextStyle(fontSize: 32, fontWeight: FontWeight.bold);
  static const title = TextStyle(fontSize: 26, fontWeight: FontWeight.bold);
  static const heading = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
  static const subhead = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
  static const bodyLg = TextStyle(fontSize: 18);
  static const body = TextStyle(fontSize: 16);
  static const bodySm = TextStyle(fontSize: 15);
  static const caption = TextStyle(fontSize: 14);
  static const label = TextStyle(fontSize: 12);
  static const micro = TextStyle(fontSize: 10, fontWeight: FontWeight.w500);
}

/// 앱 전역 테마. 현재는 기존 동작을 그대로 보존한다(렌더 변화 없음).
/// 색/타이포 토큰은 위에서 마련해 두고, ThemeData로의 편입은 점진적으로 진행한다.
class AppTheme {
  static final ThemeData theme = ThemeData(
    primarySwatch: Colors.purple,
  );
}
