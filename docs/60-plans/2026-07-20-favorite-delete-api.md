# 즐겨찾기 · 세션 삭제 API + FE Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 꿈 일기(채팅 세션)에 즐겨찾기 설정·필터 조회·삭제를 API와 FE 화면까지 완결시킨다.

**Architecture:** BE는 기존 4계층(`api → services → repositories → core/db`)을 그대로 따르고, 읽기/쓰기 라우터 분리 관례(`chatSessionApi.py`=읽기, `chatApi.py`=쓰기)에 맞춰 mark·delete는 `chatApi.py`/`ChatService`에 추가한다. FE는 `services/` 계층을 거쳐 화면이 호출하는 기존 구조를 그대로 확장한다.

**Tech Stack:** FastAPI + Prisma(Python), Flutter(Dart) + `http` 패키지.

## Global Constraints

- 이 프로젝트엔 자동화된 테스트 프레임워크가 없다. 검증은 `python -m py_compile <파일>`(BE 문법), `flutter analyze`(FE 정적 분석), 서버 기동 후 `curl`(BE 동작), 실기기/에뮬레이터 수동 조작(FE 동작)으로 한다. (CLAUDE.md)
- BE 소유권 검증은 `ChatService._get_owned_session(user_id, room_id)`를 재사용한다. 신규 로직을 따로 만들지 않는다.
- `schema.prisma`에서 `ChatMessage`/`ChatImage` → `ChatSession` 관계는 `onDelete: NoAction`이다. 세션 삭제 시 자식(`ChatMessage`, `ChatImage`)을 먼저 지우지 않으면 FK 위반이 난다. `db.tx()`로 묶는다(기존 `update_session_with_diary`와 동일 패턴).
- 즐겨찾기는 **명시적 설정** 방식이다(`PATCH` body에 `is_marked: bool`). 토글 방식이 아니다.
- 목록 화면 스와이프 삭제는 범위 밖이다. 삭제는 상세화면에서만 가능하다.
- FE 색상은 기존 화면의 다크 톤(`0xFF100D10` 배경)과 강조색(`0xFFAD46FF` 보라, `0xFFF6339A` 핑크)을 그대로 사용한다. 새 디자인 톤을 도입하지 않는다.
- BE 파일명 컨벤션: 기존 파일을 수정할 때 그 파일의 기존 관례를 따른다(예: `chatApi.py`는 path param에 `session_id`를 씀).

---

## Task 1: 즐겨찾기 PATCH API (BE)

**Files:**
- Modify: `BE/app/schemas/chatSchema.py` (끝에 `SessionMarkRequest` 추가)
- Modify: `BE/app/repositories/chatRepository.py` (끝에 `set_marked` 메서드 추가)
- Modify: `BE/app/services/chatService.py` (`create_new_chat` 메서드 뒤에 `set_marked` 메서드 추가)
- Modify: `BE/app/api/chatApi.py` (import 수정 + 끝에 라우터 추가)

**Interfaces:**
- Produces: `ChatRepository.set_marked(room_id: int, is_marked: bool)` — Prisma `ChatSession` 반환
- Produces: `ChatService.set_marked(user_id: int, room_id: int, is_marked: bool) -> bool` — 저장된 `is_marked` 값 반환
- Produces: `PATCH /chatting/session/{session_id}/mark`, body `{"is_marked": bool}` → `{"message": str, "room_id": int, "is_marked": bool}`

- [ ] **Step 1: 변경 전 상태 확인 (엔드포인트가 아직 없음을 확인)**

서버가 안 떠 있다면 새 터미널에서:
```bash
cd BE && uvicorn app.main:app --reload
```
다른 터미널에서 로그인해 토큰을 받는다(기존 계정 없으면 `/users/signup`으로 먼저 가입):
```bash
curl -X POST http://127.0.0.1:8000/users/login -H "Content-Type: application/json" -d "{\"userAccount\":\"<아이디>\",\"password\":\"<비번>\"}"
```
응답의 `access_token`을 `$TOKEN`에 넣고, 세션 하나를 만들어 `room_id`를 확보한다:
```bash
curl -X POST http://127.0.0.1:8000/chatting/session -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "{\"routine_type\":\"Morning\"}"
```
그 `room_id`로 아직 없는 엔드포인트를 호출:
```bash
curl -i -X PATCH http://127.0.0.1:8000/chatting/session/<room_id>/mark -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "{\"is_marked\":true}"
```
Expected: `404 Not Found` (경로가 아직 없음)

- [ ] **Step 2: `chatSchema.py`에 요청 스키마 추가**

파일 끝에 추가:
```python
class SessionMarkRequest(BaseModel):
    is_marked: bool
```

- [ ] **Step 3: `chatRepository.py`에 레포지토리 메서드 추가**

`get_session` 메서드 뒤, 클래스 끝에 추가:
```python
    # 즐겨찾기 상태 명시적 설정
    async def set_marked(self, room_id: int, is_marked: bool):
        return await db.chatsession.update(
            where={"room_id": room_id},
            data={"is_marked": is_marked}
        )
```

- [ ] **Step 4: `chatService.py`에 서비스 메서드 추가**

`create_new_chat` 메서드 바로 뒤에 추가:
```python
    # 즐겨찾기 상태 설정 (명시적 설정 — 토글 아님)
    async def set_marked(self, user_id: int, room_id: int, is_marked: bool) -> bool:
        await self._get_owned_session(user_id, room_id)
        session = await self.chat_repo.set_marked(room_id, is_marked)
        return session.is_marked
```

- [ ] **Step 5: `chatApi.py`에 라우터 추가**

import 줄 수정(`SessionMarkRequest` 추가):
```python
from app.schemas.chatSchema import ChatMessageRequest, ChatMessageResponse, DiaryGenerationResponse, DiaryRequest,SessionCreateRequest,SessionMarkRequest
```

파일 끝에 추가:
```python

# 4. 즐겨찾기 상태 명시적 설정 (body로 원하는 최종 상태를 지정)
@router.patch("/session/{session_id}/mark")
async def set_session_mark(session_id: int, request: SessionMarkRequest, user_id: int = Depends(get_current_user_id)):
    try:
        is_marked = await chat_service.set_marked(user_id, session_id, request.is_marked)
        return {"message": "즐겨찾기 상태 변경 완료", "room_id": session_id, "is_marked": is_marked}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
```

- [ ] **Step 6: 문법 확인**

```bash
cd BE && ../venv/Scripts/python.exe -m py_compile app/schemas/chatSchema.py app/repositories/chatRepository.py app/services/chatService.py app/api/chatApi.py
```
Expected: 에러 없이 종료(출력 없음)

- [ ] **Step 7: 실제 동작 확인**

서버가 `--reload`로 떠 있다면 자동 반영된다. Step 1과 동일한 curl을 다시 실행:
```bash
curl -i -X PATCH http://127.0.0.1:8000/chatting/session/<room_id>/mark -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "{\"is_marked\":true}"
```
Expected: `200 OK`, body `{"message":"즐겨찾기 상태 변경 완료","room_id":<room_id>,"is_marked":true}"`

남의 세션(다른 유저 토큰 또는 존재하지 않는 room_id)으로 시도해 403/404도 확인:
```bash
curl -i -X PATCH http://127.0.0.1:8000/chatting/session/999999/mark -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "{\"is_marked\":true}"
```
Expected: `404 Not Found`

- [ ] **Step 8: 커밋**

```bash
git add BE/app/schemas/chatSchema.py BE/app/repositories/chatRepository.py BE/app/services/chatService.py BE/app/api/chatApi.py
git commit -m "feat(BE): 즐겨찾기 명시적 설정 API 추가"
```

---

## Task 2: GET single session 응답에 is_marked 추가 (BE)

**Files:**
- Modify: `BE/app/schemas/chatSessionSchema.py` (`SingleSessionData`에 필드 추가)
- Modify: `BE/app/services/chatSessionService.py` (`get_single_session` 반환 dict에 필드 추가)

**Interfaces:**
- Consumes: 없음 (기존 `GET /chatting/session/single/{room_id}` 확장)
- Produces: 응답 `result.is_marked: bool`

- [ ] **Step 1: 변경 전 상태 확인**

Task 1에서 만든 `room_id`로 상세 조회:
```bash
curl -s http://127.0.0.1:8000/chatting/session/single/<room_id> -H "Authorization: Bearer $TOKEN"
```
Expected: 응답 JSON에 `is_marked` 키가 없음

- [ ] **Step 2: `chatSessionSchema.py` 수정**

`SingleSessionData` 클래스를 아래처럼 수정(`image_url` 필드 뒤에 한 줄 추가):
```python
class SingleSessionData(BaseModel):
    room_id: int
    title: str
    content: str
    created_at:Optional[datetime]
    updated_at: Optional[datetime]
    image_url: Optional[str] = None
    is_marked: Optional[bool] = None
    class Config:
        from_attributes = True
```

- [ ] **Step 3: `chatSessionService.py` 수정**

`get_single_session`의 반환 dict를 수정:
```python
            return {
                "room_id": session.room_id,
                "title": session.title,
                "content": session.content,
                "created_at":session.created_at,
                "updated_at": str(session.updated_at),
                "image_url": extracted_url,
                "is_marked": session.is_marked
            }
```

- [ ] **Step 4: 문법 확인**

```bash
cd BE && ../venv/Scripts/python.exe -m py_compile app/schemas/chatSessionSchema.py app/services/chatSessionService.py
```
Expected: 에러 없음

- [ ] **Step 5: 실제 동작 확인**

```bash
curl -s http://127.0.0.1:8000/chatting/session/single/<room_id> -H "Authorization: Bearer $TOKEN"
```
Expected: 응답에 `"is_marked":true`(Task 1에서 true로 설정했으므로) 포함

- [ ] **Step 6: 커밋**

```bash
git add BE/app/schemas/chatSessionSchema.py BE/app/services/chatSessionService.py
git commit -m "feat(BE): 세션 상세 조회 응답에 is_marked 포함"
```

---

## Task 3: 세션 삭제 DELETE API (BE)

**Files:**
- Modify: `BE/app/repositories/chatRepository.py` (끝에 `delete_session` 추가)
- Modify: `BE/app/services/chatService.py` (import 추가 + `delete_session`, `_delete_image_file` 메서드 추가)
- Modify: `BE/app/api/chatApi.py` (끝에 라우터 추가)

**Interfaces:**
- Consumes: `ChatService._get_owned_session` (Task 이전부터 존재)
- Produces: `ChatRepository.delete_session(room_id: int) -> list[str]` — 삭제 전 확보한 `image_url` 목록 반환
- Produces: `ChatService.delete_session(user_id: int, room_id: int) -> None`
- Produces: `DELETE /chatting/session/{session_id}` → `{"message": str, "room_id": int}`

- [ ] **Step 1: 변경 전 상태 확인**

```bash
curl -i -X DELETE http://127.0.0.1:8000/chatting/session/<room_id> -H "Authorization: Bearer $TOKEN"
```
Expected: `405 Method Not Allowed` (경로는 있지만 DELETE 메서드가 없음)

- [ ] **Step 2: `chatRepository.py`에 삭제 메서드 추가**

클래스 끝에 추가:
```python

    # 세션 삭제: FK가 NoAction이라 자식(메시지/이미지)을 먼저 지워야 부모 삭제가 가능하다.
    # 파일 정리는 서비스 계층 책임이므로, 지우기 전에 이미지 URL을 먼저 확보해 반환한다.
    async def delete_session(self, room_id: int) -> list[str]:
        images = await db.chatimage.find_many(where={"room_id": room_id})
        image_urls = [img.image_url for img in images if img.image_url]

        async with db.tx() as tx:
            await tx.chatmessage.delete_many(where={"room_id": room_id})
            await tx.chatimage.delete_many(where={"room_id": room_id})
            await tx.chatsession.delete(where={"room_id": room_id})

        return image_urls
```

- [ ] **Step 3: `chatService.py`에 서비스 메서드 추가**

파일 상단 import에 추가(`import os` 다음 줄):
```python
from urllib.parse import urlparse
```

`_generate_and_save_image` 메서드 뒤, 클래스 끝에 추가:
```python

    # 세션 삭제: 소유권 검증 후 DB 삭제, 성공하면 이미지 파일도 정리한다(실패해도 삭제 자체는 이미 끝난 상태이므로 무시).
    async def delete_session(self, user_id: int, room_id: int) -> None:
        await self._get_owned_session(user_id, room_id)
        image_urls = await self.chat_repo.delete_session(room_id)
        for url in image_urls:
            self._delete_image_file(url)

    def _delete_image_file(self, image_url: str) -> None:
        try:
            file_name = os.path.basename(urlparse(image_url).path)
            file_path = os.path.join("app/static/images", file_name)
            if os.path.exists(file_path):
                os.remove(file_path)
        except Exception as e:
            print(f"이미지 파일 삭제 중 오류 발생: {e}")
```

- [ ] **Step 4: `chatApi.py`에 라우터 추가**

파일 끝에 추가:
```python

# 5. 채팅 세션(꿈 일기) 삭제
@router.delete("/session/{session_id}")
async def delete_session(session_id: int, user_id: int = Depends(get_current_user_id)):
    try:
        await chat_service.delete_session(user_id, session_id)
        return {"message": "채팅방 삭제 완료", "room_id": session_id}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
```

- [ ] **Step 5: 문법 확인**

```bash
cd BE && ../venv/Scripts/python.exe -m py_compile app/repositories/chatRepository.py app/services/chatService.py app/api/chatApi.py
```
Expected: 에러 없음

- [ ] **Step 6: 실제 동작 확인**

삭제 전, 이미지가 실제로 생성된 세션인지 확인하려면 `/chatting/diary`까지 태워서 이미지 파일 경로를 하나 만들어두면 좋다(선택). 최소 검증은 메시지만 있는 세션으로도 충분:
```bash
curl -i -X DELETE http://127.0.0.1:8000/chatting/session/<room_id> -H "Authorization: Bearer $TOKEN"
```
Expected: `200 OK`, `{"message":"채팅방 삭제 완료","room_id":<room_id>}`

FK `NoAction` 제약 때문에 자식이 안 지워졌다면 이 호출 자체가 500으로 실패했을 것이다 — 200이 나왔다는 것 자체가 `ChatMessage`/`ChatImage`까지 정상적으로 함께 지워졌다는 근거다. 추가로 삭제된 세션을 다시 조회해 사라졌는지 확인:
```bash
curl -i http://127.0.0.1:8000/chatting/session/single/<room_id> -H "Authorization: Bearer $TOKEN"
```
Expected: `404 Not Found`

이미지가 있었던 경우 `BE/app/static/images/`에 해당 파일이 사라졌는지도 확인:
```bash
ls BE/app/static/images/
```

- [ ] **Step 7: 커밋**

```bash
git add BE/app/repositories/chatRepository.py BE/app/services/chatService.py BE/app/api/chatApi.py
git commit -m "feat(BE): 채팅 세션 삭제 API 추가"
```

---

## Task 4: FE 서비스 계층 확장 (api_client, api, session_service)

**Files:**
- Modify: `FE/lib/services/api_client.dart` (`patch`, `delete` 메서드 추가)
- Modify: `FE/lib/config/api.dart` (경로 2개 추가)
- Modify: `FE/lib/services/session_service.dart` (메서드 3개 추가/수정)

**Interfaces:**
- Produces: `ApiClient.patch(String path, {Object? body, bool auth = true}) -> Future<dynamic>`
- Produces: `ApiClient.delete(String path, {bool auth = true}) -> Future<dynamic>`
- Produces: `Api.sessionMark(int roomId) -> String`, `Api.deleteSession(int roomId) -> String`
- Produces: `SessionService.getAllSessions(String? userId, {bool? isMarked}) -> Future<List<dynamic>>` (기존 시그니처에 선택 인자 추가, 호출부 호환)
- Produces: `SessionService.setMarked(int roomId, bool isMarked) -> Future<bool>`
- Produces: `SessionService.deleteSession(int roomId) -> Future<void>`

- [ ] **Step 1: `api_client.dart`에 patch/delete 추가**

`post` 메서드 뒤에 추가:
```dart
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
```

- [ ] **Step 2: `api.dart`에 경로 추가**

`Session` 섹션(`singleSession` 함수 뒤)에 추가:
```dart
  static String sessionMark(int roomId) => '/chatting/session/$roomId/mark';
  static String deleteSession(int roomId) => '/chatting/session/$roomId';
```

- [ ] **Step 3: `session_service.dart` 수정**

전체를 아래로 교체:
```dart
import '../config/api.dart';
import 'api_client.dart';

/// 꿈 세션 목록/상세 조회, 즐겨찾기 설정, 삭제 (chatSessionApi + chatApi 일부).
class SessionService {
  /// 유저의 전체 세션 목록(result 리스트)을 반환한다.
  /// isMarked가 true면 즐겨찾기한 세션만 필터링해 받아온다.
  Future<List<dynamic>> getAllSessions(String? userId, {bool? isMarked}) async {
    final query = isMarked == null ? '' : '&is_marked=$isMarked';
    final data =
        await apiClient.get('${Api.allSessions}?user_id=$userId$query');
    return (data['result'] as List<dynamic>?) ?? [];
  }

  /// 단일 세션 상세(result 맵)를 반환한다. 없으면 null.
  Future<Map<String, dynamic>?> getSession(int roomId) async {
    final data = await apiClient.get(Api.singleSession(roomId));
    return data['result'] as Map<String, dynamic>?;
  }

  /// 즐겨찾기 상태를 명시적으로 설정하고, 저장된 값을 반환한다.
  Future<bool> setMarked(int roomId, bool isMarked) async {
    final data = await apiClient
        .patch(Api.sessionMark(roomId), body: {'is_marked': isMarked});
    return data['is_marked'] as bool;
  }

  /// 세션(꿈 일기)을 삭제한다.
  Future<void> deleteSession(int roomId) async {
    await apiClient.delete(Api.deleteSession(roomId));
  }
}

final sessionService = SessionService();
```

- [ ] **Step 4: 정적 분석**

```bash
cd FE && flutter analyze lib/services/api_client.dart lib/config/api.dart lib/services/session_service.dart
```
Expected: `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add FE/lib/services/api_client.dart FE/lib/config/api.dart FE/lib/services/session_service.dart
git commit -m "feat(FE): 즐겨찾기·삭제 API 서비스 계층 추가"
```

---

## Task 5: 꿈 목록 화면 — 필터 + 즐겨찾기 토글 (FE)

**Files:**
- Modify: `FE/lib/screens/dream/dream_list_screen.dart`

**Interfaces:**
- Consumes: `sessionService.getAllSessions(userId, {isMarked})`, `sessionService.setMarked(roomId, isMarked)` (Task 4)

- [ ] **Step 1: state 필드 추가**

`bool _isMenuOpen = false;` 바로 뒤에 추가:
```dart
  bool _showOnlyMarked = false;
```

- [ ] **Step 2: `_fetchDreams` 수정 — 필터 반영 + is_marked 포함**

`Future<void> _fetchDreams() async {` 전체를 아래로 교체:
```dart
  Future<void> _fetchDreams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('user_id');

      final sessionList = await sessionService.getAllSessions(userId,
          isMarked: _showOnlyMarked ? true : null);

      if (!mounted) return;
      setState(() {
          _dreamList = sessionList.map((session) {
            String rawDate = session['updated_at'] ?? '';
            String formattedDate =
                rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
            String? realImageUrl = session['image_url'];
            String displayImageUrl = (realImageUrl != null &&
                    realImageUrl.isNotEmpty)
                ? realImageUrl.replaceAll(
                    'localhost', '13.209.97.107') // 혹시 모를 로컬호스트 에러 방어
                : (session['routine_type'] == 'night'
                    ? "https://placehold.co/400x300/2C2530/FFFFFF/png?text=Night+Dream"
                    : "https://placehold.co/400x300/1F1B21/FFFFFF/png?text=Morning+Dream");

            return {
              "id": session['room_id'],
              "date": formattedDate,
              "title": session['title'] ?? "제목 없는 꿈",
              "content": session['content'] ?? "일기 내용이 없습니다.",
              "image_url": displayImageUrl,
              "is_marked": session['is_marked'] == true
            };
          }).toList();
          _isLoading = false;
        });
    } catch (e) {
      if (!mounted) return;
      _loadMockData();
    }
  }
```

- [ ] **Step 3: 즐겨찾기 토글 메서드 추가**

`_fetchReport` 메서드 앞에 추가:
```dart
  Future<void> _toggleMarked(int index) async {
    final dream = _dreamList[index];
    final bool newValue = !(dream['is_marked'] == true);
    try {
      await sessionService.setMarked(dream['id'], newValue);
      if (!mounted) return;
      setState(() {
        _dreamList[index]['is_marked'] = newValue;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('즐겨찾기 변경에 실패했습니다.')));
    }
  }
```

- [ ] **Step 4: 필터 칩 UI 추가**

`build` 메서드 안, "내 꿈나라 / 전체 N개" `Padding` 블록(`_buildEmotionStatisticsArea()` 바로 뒤) 다음에 새 `Padding` 블록 삽입:
```dart
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('전체'),
                    selected: !_showOnlyMarked,
                    selectedColor: Color(0xFF8F6CFF),
                    backgroundColor: Color(0xFF1F1B21),
                    labelStyle: TextStyle(color: Colors.white),
                    onSelected: (_) {
                      setState(() => _showOnlyMarked = false);
                      _fetchDreams();
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('즐겨찾기'),
                    selected: _showOnlyMarked,
                    selectedColor: Color(0xFF8F6CFF),
                    backgroundColor: Color(0xFF1F1B21),
                    labelStyle: TextStyle(color: Colors.white),
                    onSelected: (_) {
                      setState(() => _showOnlyMarked = true);
                      _fetchDreams();
                    },
                  ),
                ],
              ),
            ),
```
(정확한 삽입 위치: 기존 코드에서 `Text('내 꿈나라', ...)` 를 담은 `Padding`이 끝나는 `),` 바로 다음, `Expanded(` 바로 이전.)

- [ ] **Step 5: 카드에 하트 아이콘 오버레이 + 탭 결과 처리**

`itemBuilder`의 호출부 수정:
```dart
                      itemBuilder: (context, index) {
                        return _buildDreamCard(_dreamList[index], index);
                      },
```

`_buildDreamCard` 전체를 아래로 교체:
```dart
  Widget _buildDreamCard(Map<String, dynamic> dream, int index) {
    final bool isMarked = dream['is_marked'] == true;
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.pushNamed(context, '/chat_detail',
            arguments: dream['id']);
        if (result == true) _fetchDreams();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image:
                NetworkImage(dream['image_url'] ?? "https://placehold.co/400"),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dream['date'] ?? '',
                      style: TextStyle(color: Color(0xFF746E7A), fontSize: 12)),
                  SizedBox(height: 4),
                  Text(dream['title'] ?? '',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  Text(dream['content'] ?? '',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _toggleMarked(index),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMarked ? Icons.favorite : Icons.favorite_border,
                    color: isMarked ? Color(0xFFF6339A) : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 6: 정적 분석**

```bash
cd FE && flutter analyze lib/screens/dream/dream_list_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 7: 실기기 수동 확인**

```bash
cd FE && flutter run
```
확인 항목:
- 꿈 목록에 "전체/즐겨찾기" 칩이 보이고, 탭하면 목록이 필터링된다
- 카드 우상단 하트를 탭하면 즉시 채워짐/빈 상태가 바뀌고, 상세화면 재진입 없이도 유지된다(로컬 상태 갱신 확인)
- 하트를 탭해도 카드 자체의 상세화면 이동은 발생하지 않는다

- [ ] **Step 8: 커밋**

```bash
git add FE/lib/screens/dream/dream_list_screen.dart
git commit -m "feat(FE): 꿈 목록 화면에 즐겨찾기 필터·토글 추가"
```

---

## Task 6: 꿈 상세 화면 — 즐겨찾기 토글 + 삭제 (FE)

**Files:**
- Modify: `FE/lib/screens/dream/dream_detail_screen.dart`

**Interfaces:**
- Consumes: `sessionService.setMarked(roomId, isMarked)`, `sessionService.deleteSession(roomId)` (Task 4)
- Produces: 삭제 성공 시 `Navigator.pop(context, true)` — Task 5의 목록 화면이 이 결과값으로 재조회 여부를 판단

- [ ] **Step 1: state 필드 추가**

`int? _currentRoomId;` 바로 뒤에 추가:
```dart
  bool _isMarked = false;
```

- [ ] **Step 2: `_fetchDreamDetail` 수정 — is_marked 반영**

`Future<void> _fetchDreamDetail(int roomId) async {` 전체를 아래로 교체:
```dart
  Future<void> _fetchDreamDetail(int roomId) async {
    try {
      final result = await sessionService.getSession(roomId);
      if (!mounted) return;
      setState(() {
        _dreamData = result;
        _isMarked = result?['is_marked'] == true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _loadMockData();
    }
  }
```

- [ ] **Step 3: 즐겨찾기 토글 + 삭제 확인 메서드 추가**

`_loadMockData` 메서드 뒤에 추가:
```dart
  Future<void> _toggleMarked() async {
    if (_currentRoomId == null) return;
    final bool newValue = !_isMarked;
    try {
      await sessionService.setMarked(_currentRoomId!, newValue);
      if (!mounted) return;
      setState(() => _isMarked = newValue);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('즐겨찾기 변경에 실패했습니다.')));
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1B21),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('꿈 일기 삭제',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('이 꿈 일기를 삭제할까요? 되돌릴 수 없습니다.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('삭제',
                  style: TextStyle(
                      color: Color(0xFFF6339A), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || _currentRoomId == null) return;

    try {
      await sessionService.deleteSession(_currentRoomId!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제에 실패했습니다.')));
    }
  }
```

- [ ] **Step 4: AppBar에 아이콘 추가**

`appBar: AppBar(` 블록의 `leading: IconButton(...)` 뒤에 `actions` 추가:
```dart
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('꿈 상세 기록',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isMarked ? Icons.favorite : Icons.favorite_border,
              color: _isMarked ? Color(0xFFF6339A) : Colors.white,
            ),
            onPressed: _toggleMarked,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _confirmDelete,
          ),
        ],
      ),
```

- [ ] **Step 5: 정적 분석**

```bash
cd FE && flutter analyze lib/screens/dream/dream_detail_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 6: 실기기 수동 확인**

```bash
cd FE && flutter run
```
확인 항목:
- 상세화면 앱바 하트 탭 → 즉시 채움/빈 상태 전환, 목록으로 돌아가 재진입해도 상태 유지(BE 반영 확인)
- 휴지통 탭 → 확인 다이얼로그 표시 → "취소" 시 아무 일도 안 일어남
- "삭제" 확정 → 목록 화면으로 돌아가면서 해당 카드가 사라짐(Task 5의 `_fetchDreams()` 재호출 확인)

- [ ] **Step 7: 커밋**

```bash
git add FE/lib/screens/dream/dream_detail_screen.dart
git commit -m "feat(FE): 꿈 상세 화면에 즐겨찾기·삭제 추가"
```

---

## Task 7: FE 코드 컨벤션 문서 작성

**Files:**
- Create: `docs/fe-conventions.md`

**Interfaces:**
- Consumes: 없음 (Task 1~6에서 실제로 쓰인 패턴을 문서화)

- [ ] **Step 1: 문서 작성**

`docs/fe-conventions.md` 생성:
```markdown
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
```

- [ ] **Step 2: 커밋**

```bash
git add docs/fe-conventions.md
git commit -m "docs: FE 코드 컨벤션 문서 추가"
```

---

## Self-Review 결과

- **스펙 커버리지**: 설계 문서의 BE 3개 엔드포인트(PATCH mark / DELETE / GET single 확장) = Task 1~3, FE 서비스·목록·상세 = Task 4~6, 컨벤션 문서 = Task 7. 스펙 전 항목 매핑 완료.
- **플레이스홀더 스캔**: `<room_id>`/`$TOKEN`/`<아이디>`는 curl 예시에서 실행자가 실제 값으로 채워야 하는 자리로, 코드 플레이스홀더가 아니다. 코드 블록 안에는 TBD/TODO 없음.
- **타입 일관성**: `set_marked`는 BE·FE 전 구간에서 `is_marked: bool`로 통일. `delete_session`은 BE에서 `image_url` 정리까지 책임지고 FE는 단순 호출만 하는 것으로 일관됨. `SessionService.getAllSessions`의 `isMarked` 선택 인자는 Task 4에서 정의한 시그니처를 Task 5가 그대로 사용.
