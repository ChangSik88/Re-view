# 즐겨찾기 · 세션 삭제 API + FE 설계

## 목표
`ChatSession.is_marked` 컬럼과 삭제 기능이 스키마/DB 쿼리 단에는 이미 있었지만 이를 조작하는 API·화면이 없었다. 즐겨찾기 설정, 필터 조회, 세션(꿈 일기) 삭제를 API와 FE 화면까지 완결시킨다.

## 범위
- 신규: `PATCH /chatting/session/{session_id}/mark`, `DELETE /chatting/session/{session_id}`
- 확장: `GET /chatting/session/single/{room_id}` 응답에 `is_marked` 추가
- FE: 서비스 계층(`api_client`/`api`/`session_service`), 꿈 목록 화면, 꿈 상세 화면
- 신규 문서: `docs/fe-conventions.md`
- **범위 밖**: 목록 화면 스와이프 삭제(상세화면 삭제만 지원, 사용자 확정), 즐겨찾기 토글 방식은 명시적 설정(바디로 `is_marked` 지정, 토글 방식 아님)

## 백엔드 설계

### 계층 배치
읽기(`chatSessionApi.py`/`ChatSessionService`)와 쓰기(`chatApi.py`/`ChatService`)가 이미 분리돼 있는 기존 구조를 따른다. mark·delete는 쓰기 동작이므로 `chatApi.py` + `ChatService`에 추가하고, 소유권 검증은 기존 `ChatService._get_owned_session`을 재사용한다. path param 이름도 `chatApi.py`의 기존 관례(`session_id`)를 따른다.

### `PATCH /chatting/session/{session_id}/mark`
- Request body (`chatSchema.py`에 `SessionMarkRequest` 추가): `{"is_marked": bool}`
- 흐름: `_get_owned_session`으로 소유권 확인 → `ChatRepository.set_marked(room_id, is_marked)` → `db.chatsession.update(where={"room_id": room_id}, data={"is_marked": is_marked})`
- Response(response_model 없이 dict, 기존 `create_session`과 동일 스타일): `{"message": "즐겨찾기 상태 변경 완료", "room_id": ..., "is_marked": ...}`
- 에러: `ValueError`→404, `PermissionError`→403 (기존 라우터들과 동일 패턴)

### `DELETE /chatting/session/{session_id}`
- `schema.prisma`에서 `ChatMessage`/`ChatImage` → `ChatSession` FK가 `onDelete: NoAction`이라 자식을 먼저 지우지 않으면 부모 삭제 시 FK 위반이 난다. `ChatRepository.delete_session`을 아래 순서로 구현:
  1. 트랜잭션 밖에서 `db.chatimage.find_many(where={"room_id": room_id})`로 지울 이미지의 `image_url` 목록을 먼저 확보
  2. `db.tx()` 안에서 `chatmessage.delete_many` → `chatimage.delete_many` → `chatsession.delete` 순서로 삭제 (기존 `update_session_with_diary`와 동일하게 `db.tx()` 패턴)
  3. 트랜잭션 커밋 후 확보해둔 `image_url` 목록으로 로컬 파일(`app/static/images/<uuid>.png`) 삭제 시도. `urlparse(image_url).path`에서 basename만 뽑아 경로 구성. 파일 삭제는 트랜잭션 밖·best-effort — 실패해도 세션 삭제 자체는 이미 끝난 상태이므로 `print`로 로그만 남기고 무시한다 (`_generate_and_save_image`의 기존 예외 처리와 대칭).
- 흐름: `_get_owned_session`으로 소유권 확인 → `ChatRepository.delete_session(room_id)` 호출 → 반환된 `image_url` 목록으로 파일 정리
- Response: `{"message": "채팅방 삭제 완료", "room_id": ...}`
- 에러: 동일하게 404/403

### `GET /chatting/session/single/{room_id}` 확장
- `SingleSessionData`(`chatSessionSchema.py`)에 `is_marked: Optional[bool]` 추가
- `ChatSessionService.get_single_session`이 반환하는 dict에 `"is_marked": session.is_marked` 한 줄 추가
- 상세화면이 하트 아이콘 초기 상태(채움/빈 상태)를 그리려면 필수

## 프론트엔드 설계

### 서비스 계층
- `api_client.dart`: `get`/`post`와 동일한 패턴으로 `patch`/`delete` 메서드 추가 (헤더 처리·디코드 로직 재사용)
- `api.dart`: `sessionMark(int roomId)`, `deleteSession(int roomId)` 경로 함수 추가
- `session_service.dart`:
  - `getAllSessions(String? userId, {bool? isMarked})` — 기존 시그니처에 선택 인자 추가, `isMarked`가 null이 아니면 쿼리에 `&is_marked=$isMarked` 붙임 (BE는 이미 지원, FE만 안 쓰고 있었음)
  - `setMarked(int roomId, bool isMarked)` — PATCH 호출 후 갱신된 `is_marked` bool 반환
  - `deleteSession(int roomId)` — DELETE 호출, 반환값 없음

### 꿈 목록 화면 (`dream_list_screen.dart`)
- "내 꿈나라 / 전체 N개" 배지 옆에 "전체 / 즐겨찾기" 필터 칩 2개 추가. 상태 `_showOnlyMarked` bool로 관리(초기값 `false` = "전체" 선택), 탭 시 `_fetchDreams()` 재호출(내부에서 `sessionService.getAllSessions(userId, isMarked: _showOnlyMarked ? true : null)` 호출). "전체 N개" 배지는 현재 필터링된 `_dreamList.length`를 그대로 표시(기존 로직 유지, 별도 분기 불필요)
- 각 꿈 카드 우상단에 하트 아이콘 오버레이. 탭하면 해당 카드만 `sessionService.setMarked` 호출 후 `_dreamList` 로컬 상태 갱신(리스트 전체 재조회 없이 해당 항목만 업데이트). 카드 자체의 상세 이동 탭과 겹치지 않도록 별도 `GestureDetector`로 감싼다.
- 카드 탭 → 상세화면 이동을 `await Navigator.pushNamed(...)`로 바꾸고, 상세화면에서 삭제 후 `pop(context, true)`로 돌아오면 결과가 `true`일 때 `_fetchDreams()` 재호출

### 꿈 상세 화면 (`dream_detail_screen.dart`)
- `AppBar.actions`에 하트 아이콘(즐겨찾기 토글) + 휴지통 아이콘(삭제) 추가
- 하트 탭: `sessionService.setMarked` 호출 후 `_dreamData['is_marked']` 갱신, 아이콘 즉시 반영
- 휴지통 탭: `AlertDialog`로 확인("이 꿈 일기를 삭제할까요? 되돌릴 수 없습니다") → 확인 시 `sessionService.deleteSession` 호출 → 성공 시 `Navigator.pop(context, true)`
- 색상/스타일은 기존 화면 값 그대로 사용(다크 배경 `0xFF100D10`, 강조색 보라 계열 `0xFFAD46FF`) — 새 위젯도 이 톤에 맞춘다

## 컨벤션 문서 (`docs/fe-conventions.md`, 신규)
FE에는 색상·타이포 문서(`design-tokens.md`)만 있고 코드 작성 패턴 문서가 없다. 이번 구현에서 실제로 따르는 기존 패턴을 캐탈로그화한다:
- 서비스 클래스: 싱글턴 인스턴스 export, 클래스/메서드 doc comment(한국어), `data['result']` 언래핑, 실패 시 `ApiException`
- `Api` 클래스: 도메인별 주석 섹션, path param 있는 경로는 함수형(`static String x(int id) => ...`)
- 화면: `StatefulWidget` + `_XScreenState`, `didChangeDependencies`에서 route arguments 파싱, 실패 시 mock 데이터 폴백 또는 `SnackBar`, 비동기 후 `if (!mounted) return` 가드
- 색/타이포: 신규 위젯은 `AppColors`/`AppTextStyles` 참조(점진적 교체 방침은 `app_theme.dart` 주석과 동일)

## 검증 (pass 조건)
1. BE: 각 수정 파일 `python -m py_compile` 통과
2. BE: 서버 기동 후 `curl`로 PATCH mark(즐겨찾기 on/off), DELETE(삭제 후 재조회 시 404) 확인. 삭제 후 연결된 `ChatMessage`/`ChatImage` 로우가 남지 않는지, 이미지 파일이 디스크에서도 지워지는지 확인
3. BE: 남의 세션에 PATCH/DELETE 시도 시 403 확인
4. FE: `flutter run`으로 실기기/에뮬레이터에서 목록 필터 칩, 카드 하트, 상세화면 하트·삭제 다이얼로그·삭제 후 목록 갱신까지 실제 조작으로 확인
