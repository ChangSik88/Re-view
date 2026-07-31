# FE 코드 컨벤션

`FE/lib/`의 실제 코드에서 관찰한 패턴입니다. 색·타이포는 `docs/design-tokens.md`를 보세요. 여기는 코드 작성 패턴만 다룹니다.

## 서비스 계층 (`lib/services/`)

- 도메인별 파일 하나에 클래스 하나(`SessionService`, `StoreService`, `ReportService` ...), 파일 끝에 싱글턴 인스턴스를 export: `final xService = XService();`
- 클래스에 한국어 doc comment로 "이 서비스가 어떤 API 도메인을 감싸는지" 한 줄 명시. 각 메서드에도 반환값 형태(`result` 맵인지 리스트인지, 없으면 null인지)를 doc comment로 남긴다.
- HTTP 호출은 전부 `api_client.dart`의 `apiClient`(싱글턴)를 통한다. 응답은 `data['result']`를 언래핑해서 반환하고, 실패는 `ApiException`으로 통일(서비스에서 잡지 않고 화면으로 전파).
- 새 HTTP 동사가 필요하면 `api_client.dart`에 `get`/`post`와 같은 패턴으로 메서드를 추가한다(헤더 처리·디코드 로직 재사용).

## 경로 관리 (`lib/config/api.dart`)

- 모든 엔드포인트 경로는 `Api` 클래스의 static 필드/함수로만 정의한다. 서비스나 화면에 경로 문자열을 직접 쓰지 않는다.
- path param이 있는 경로는 함수형으로: `static String x(int id) => '/domain/$id';`
- 도메인별로 주석 섹션을 나눠 묶는다(`// Auth`, `// Chat (chatApi)` 등 — 대응하는 BE 라우터 파일명을 주석에 남기면 추적이 쉽다).

## 화면 (`lib/screens/`)

- `StatefulWidget` + `_XScreenState` 명명, 기능별 폴더(`auth/`, `chat/`, `dream/`, `store/`, `home/`)에 배치.
- route argument는 `didChangeDependencies`에서 `ModalRoute.of(context)?.settings.arguments`로 파싱한다(생성자 대신 — 라우트 기반 네비게이션이라).
- 비동기 호출 후 `setState` 전에는 항상 `if (!mounted) return;` 가드를 넣는다.
- API 실패 시 화면 성격에 따라 둘 중 하나: 목록/상세처럼 "보여줄 데이터"가 필요한 화면은 `_loadMockData()`류 폴백으로 빈 화면을 막고, 액션(생성/수정/삭제)류는 `ScaffoldMessenger`의 `SnackBar`로 실패를 알린다.
- 화면 간 결과 전달은 `Navigator.pop(context, <값>)` + 호출부의 `await Navigator.pushNamed(...)` 결과 확인 패턴을 쓴다(상세화면 삭제 → 목록 갱신이 예시).

## 색·타이포

- 신규 위젯은 색 리터럴 대신 `AppColors`/`AppTextStyles`(`lib/theme/app_theme.dart`)를 참조한다. 기존 화면의 하드코딩 색(`Color(0xFF...)`)은 점진적으로 교체할 뿐, 지금 당장 손대지 않는다(기존 방침, `app_theme.dart` 주석 참고).
