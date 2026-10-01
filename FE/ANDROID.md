# Android 휴대폰 실행

Flutter 앱입니다. Figma 디자인을 `lib/review/` 화면에 반영했습니다.
로그인 화면의 **디자인 미리보기 (예시 데이터)**로 서버 로그인 없이 화면과 이동을 확인할 수 있습니다.
미리보기에서는 실제 AI 요청·주문·계정 데이터 변경을 수행하지 않습니다.

1. Flutter stable SDK와 Android Studio를 설치합니다.
2. Android Studio에서 Android SDK, Platform Tools, Command-line Tools를 설치합니다.
3. `flutter doctor -v`로 검사하고 `flutter doctor --android-licenses`에서 약관을 검토합니다.
4. 휴대폰의 USB 디버깅을 켜고 데이터 케이블로 연결한 후 디버깅 허용을 승인합니다.
5. `flutter devices`로 휴대폰 ID를 확인합니다.

FE 폴더에서 실행:

```powershell
.\run-android.ps1 -DeviceId '<휴대폰 ID>'
```

Flutter가 PATH에 없으면 `-FlutterPath 'C:\경로\flutter\bin\flutter.bat'`를 지정합니다.
이 작업 공간의 `../../.tools/flutter`도 자동 탐색합니다.
한글 작업 경로에서 발생한 Flutter 도구 오류를 피하도록 실행 스크립트는
이 작업 공간을 임시 `R:` 드라이브로 연결합니다. 다른 용도로 사용 중인
`R:` 드라이브는 덮어쓰지 않습니다. 재부팅 후에는 스크립트가 다시 연결합니다.
Windows에서 플러그인 심볼릭 링크 오류가 나면 `Win + R` →
`ms-settings:developers`에서 개발자 모드를 켜세요.

로그인·AI 채팅은 서버와 계정이 필요합니다. 기본 주소는 `lib/config/api.dart`입니다.
다른 서버를 사용할 때는 `-ApiBaseUrl 'https://your-api.example.com'`을 추가합니다.

검사 및 APK 생성:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

APK 위치: `build/app/outputs/flutter-apk/app-debug.apk`.
배포용 서명과 스토어 등록은 별도 작업입니다.

## 이 PC에서 확인한 상태 (2026-09-24)

- Flutter 3.47.5 / Dart 3.13.4, Android Studio 및 Android SDK 설치 완료.
- 로그인 화면 표시와 빈 입력 검증 테스트 통과.
- 디버그 APK 빌드 성공. 최신 디자인 빌드의 휴대폰 설치는 USB 연결 확인이 필요합니다.
- 기존 코드 분석 경고/권고 453건은 별도 정리가 필요합니다.
- Windows C:/R: 경로 간 Kotlin 캐시 오류를 피하기 위해
  `android/gradle.properties`에서 증분 컴파일을 끄고 in-process 컴파일을 사용합니다.
  증분 빌드 속도는 느려질 수 있습니다.

## 반영 범위와 API 연결

- Pretendard 로컬 폰트, Figma 원본 이미지·SVG, 공통 SafeArea. 기본 좌우 여백은 24px이며 홈·설정은 20px, 스토어는 30px로 원본에 맞춥니다.
- 홈 → 모닝/나이트 채팅, 루틴 선택 메뉴, 날짜별 기록, 북마크 ↔ 캘린더, 검색.
- AI 요약/전문/인사이트 공통 레이아웃, 분석 X → 해당 루틴 홈.
- 장소·등장인물·감정·생활·기타 메모를 수정한 뒤 **정보가 맞아요**로 확인합니다. 실제 모드에서는 확인 정보를 채팅 이력에 저장한 후 이야기를 생성하고 결과 화면으로 이동합니다. 수정 완료만 누를 때는 전송하지 않습니다.
- 상품 카테고리/상세, 계정별 로컬 장바구니, 개별·전체 삭제, 설정 화면.
- 로그인 모드는 기존 채팅·일기·북마크·상품·리포트 API를 사용합니다. 실패를 예시 데이터로 대체하지 않습니다.
- 감정 비율과 일기별 상세 해석 API는 없어 실제 모드에서 안내를 표시합니다. 주간 리포트는 기존 API를 사용합니다.
- 검색은 불러온 기록의 제목·본문·태그를 검색합니다. 의미 기반 검색 API는 아직 없습니다.
- 결제·푸시 발송·약관 문서 API는 아직 연결되지 않았습니다. 구매 완료를 표시하지 않으며 알림 설정만 기기에 저장합니다.
- 날짜는 목록 API의 `updated_at`을 사용합니다(`created_at`이 제공되면 우선 사용). 원본 작성일을 보존하려면 목록 API가 작성일을 제공해야 합니다.

화면 검증 이미지 생성: `flutter test --no-pub tool/render_preview_test.dart`
출력 폴더: `build/design-preview/`.

2026-09-29 프로토타입 비교: 홈 2주 캘린더, 이미지 전용 스토어 미리보기,
공통 헤더·버튼 크기, 분석 상단바·탭·사진, 북마크 썸네일,
채팅 말풍선·정보 카드·마이크/전송 아이콘, 상품 카드와 설정 아이콘을 조정했습니다.
SVG는 `tool/index_figma_assets.ps1`로 원본 크기 메타데이터를 생성해 사용합니다.
14개 화면/탭 렌더링을 지원하며, 서버에 없는 감정 변화 수치·결제·푸시 기능은
프로토타입과 동일한 실제 결과로 제공되지 않습니다.

## 음성 입력

채팅 입력바 왼쪽 마이크 → 최초 마이크 권한 허용 → 한국어로 말하기 → 마이크 다시 눌러 종료 → 내용 확인 후 전송.
인식 중간 결과는 입력칸에서 갱신되며, 기존 입력은 유지됩니다. 자동 전송하지 않습니다.
화면을 닫거나 앱이 백그라운드로 가면 인식을 취소합니다. 휴대폰의 한국어 음성 인식 서비스가 필요하며 인터넷 연결이 필요할 수 있습니다.
휴대폰 내장 마이크를 사용합니다. Bluetooth 전용 권한은 요청하지 않습니다.
구현 참고: https://pub.dev/packages/speech_to_text
