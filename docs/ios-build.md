# iOS 빌드와 설치

Android와 같은 FE Flutter 소스로 루미 이미지, 대화, 로그인 기능을 사용합니다. iOS 최소 버전은 기존 프로젝트의 15.0이며 마이크/음성 인식 사용 설명은 Info.plist에 포함되어 있습니다. 한국어 권한 안내와 앱 표시 이름 Re-view를 설정했습니다.

## Mac 없이 빌드 검증

GitHub Actions의 `iOS build validation`은 macOS 26에서 Flutter 3.47.5로 채팅 테스트, 서명 없는 iPhone 빌드, 시뮬레이터 빌드를 수행합니다. FE 변경을 main 또는 codex/emotion-statistics에 푸시하거나 PR을 만들면 실행됩니다. 기본 브랜치에 병합한 후에는 Actions에서 수동 실행도 가능합니다.

성공한 실행의 `Re-view-iOS-실행번호` 아티팩트에는 두 ZIP이 있습니다.

- Re-view-unsigned-iphone.zip: 서명 전 실제 기기용 Runner.app. 아이폰에 바로 설치할 수 있는 IPA가 아닙니다.
- Re-view-simulator.zip: Mac의 iOS Simulator용 Runner.app. 실제 아이폰에는 설치되지 않습니다.

서명 키나 Apple 계정 비밀번호를 이 워크플로에 넣지 않습니다. ZIP은 14일 보관됩니다. 빌드 통과는 실제 기기의 로그인·채팅·음성 입력 검증을 대신하지 않습니다.

## 실제 아이폰 설치

Mac을 사용할 수 있으면 Xcode에서 `FE/ios/Runner.xcworkspace`를 열고 Apple 계정의 Team과 소유한 고유 Bundle Identifier를 설정한 뒤 연결한 아이폰에 실행합니다. 현재 com.example.frontend는 개발용 임시 식별자이므로 배포 전에 바꿔야 합니다. 일반 Apple 계정의 Personal Team 설치에는 Apple의 기한/기능 제한이 적용됩니다.

Mac 없이 TestFlight로 배포하려면 Apple Developer Program 등록과 인증서·프로비저닝 설정을 추가해야 합니다. 현재 워크플로는 TestFlight 업로드나 배포용 서명을 하지 않습니다.

확인 항목: 로그인 전 홈, 자동 로그인, 모닝/나이트 이미지, 키보드와 하단 입력창, 실제 AI 응답, 마이크/음성 인식 허용 및 거부, 앱 재시작 후 기록 유지.

참고: https://docs.flutter.dev/platform-integration/ios/setup
