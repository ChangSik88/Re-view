# 앱 리디자인 — BE 갭 조사

Figma 앱 리디자인([인벤토리](../30-design/02-figma-app-inventory.md))을 구현하려면 BE에 무엇이 있고 무엇이 없는지 조사한 결과다.

조사일: 2026-09-19 / 조사 범위: `BE/prisma/schema.prisma`, `BE/app/**`, `FE/lib/services/**`, `FE/lib/config/api.dart`

**판단 기조**: 기존 것을 억지로 늘려 쓰기보다 기능을 분리한다. 아래 각 항목에 **재활용 / 확장 / 신규** 를 명시했고, 같은 데이터에 조건만 다른 경우에만 재활용으로 분류했다.

## 한눈에 보기

현재 BE 엔드포인트는 **14개가 전부**다.

| 도메인 | 엔드포인트 |
|---|---|
| users | `POST /users/signup`, `POST /users/login` |
| chatting | `POST /chatting/session`, `POST /chatting/message`, `POST /chatting/diary`, `PATCH /chatting/session/{id}/mark`, `DELETE /chatting/session/{id}` |
| chatting (조회) | `GET /chatting/session/all`, `GET /chatting/session/single/{id}`, `GET /chatting/history/{id}` |
| report | `POST /report/analyze`, `GET /report` |
| item | `GET /item/list`, `GET /item/detail/{id}` |

## 가장 중요한 사실 — 스키마는 있는데 API가 없다

`Purchase`, `Payment`, `Shipment`, `UserAddress`, `UserSocialAccount`, `UserDevice`, `NotificationLog`, `NotificationType`, `UserNotificationSetting`, `Term`, `UserConsent`, `CustomerInquiry`, `DiaryEntry`, `AuthToken` — 전부 테이블로 존재하지만 **이들을 읽거나 쓰는 엔드포인트가 하나도 없다.**

특히 **구매는 아직 기능이 아니다.** `FE/lib/services/store_service.dart`에는 조회 2개만 있고, `store_detail_screen.dart`의 "구매 완료!" 다이얼로그는 서버를 호출하지 않는 로컬 UI다. 리디자인의 [장바구니] [구매하기] 버튼을 살리려면 구매 흐름 전체를 새로 만들어야 한다.

## 기능별 갭

### 1. 감정 통계 3종 원형 — **신규**

- **필요**: 행복 31% / 불안 42% / 편안 17% 형태의 감정별 비율.
- **현재**: `WeeklySession.weekly_content`가 **자유 텍스트 한 덩어리**다. `reportManager.generate_insight`의 프롬프트가 "3~4문장 이내, 구체적 사물 언급 금지"를 지시하므로 출력은 산문이다. 비율은커녕 감정 이름조차 구조화돼 있지 않다.
- **판단**: **분리**. `WeeklySession`을 확장하지 않는다. 산문 리포트와 감정 수치는 목적도 생명주기도 다르다. 감정 집계 전용 모델과 엔드포인트를 새로 만든다.
- **덧붙임**: `ChatRoom.tags`가 `VarChar(50)`에 쉼표 문자열이라 집계용으로 못 쓴다. 감정을 집계하려면 정규화된 저장이 필요하다.

### 2. AI 감정 인사이트 (감정 변화 라인차트) — **신규**

- **필요**: 날짜별 감정 점수 시계열(4/10~4/13 × 불안·기대·설렘), 어제 꿈 → 오늘 감정 전이 문구, 추천 카드.
- **현재**: 날짜별 감정 점수를 저장하는 곳이 없다. `report`는 최근 꿈 **3개**만 보고 날짜 범위와 무관하게 동작한다.
- **판단**: **신규**. 1번의 감정 집계 모델을 시계열로 설계하면 2번이 그 위에 얹힌다. 1번과 2번은 같은 저장소를 공유하도록 함께 설계할 것.

### 3. 꿈 / 하루 분리 조회 — **재활용(필터 추가)**

- **필요**: "내 꿈나라"(모닝)와 "내 일기장"(나이트)이 별도 화면이다.
- **현재**: `ChatRoom.routine_type`은 있으나 `GET /chatting/session/all`의 필터는 `is_marked` 하나뿐이다.
- **판단**: **재활용**. 같은 테이블·같은 응답 형태에 조건만 다르므로 `routine_type` 쿼리 파라미터를 추가한다. 화면이 갈린다고 API까지 가를 이유는 없다.

### 4. Dream Calendar (월간 + 주간 위젯) — **확장**

- **필요**: 월별 날짜에 기록 유무·감정 이모지 표시, 특정 날짜 선택 시 그날의 기록.
- **현재**: 날짜 범위 조회가 없다. `session/all`은 전체를 다 내려준다. 월별 칩("전체 6 / 4월 6 / 5월 0")도 불가능하다.
- **판단**: **확장**. 데이터(`ChatRoom.created_at`)는 그대로 쓰고 날짜 범위 파라미터와 월별 집계 엔드포인트를 더한다. 감정 이모지는 1번에 의존한다.

### 5. 채팅 중 구조화 정보 카드 — **분리**

- **필요**: 등장인물 / 장소 / 감정 / 상황 / 기타 메모 5개 항목을 대화에서 추출하고, 항목별로 수정 다이얼로그를 띄운다.
- **현재**: `AIAnalysisResponse`는 `theme`(주제), `vibe`(분위기), `suggested_feelings`(감정 키워드 3개), `ai_reply` 4필드다. 일기 생성은 `selected_keywords: List[str]`만 받는다.
- **판단**: **분리**. `suggested_feelings`를 5개 항목으로 늘리는 식으로 재활용하면 안 된다. 기존 필드는 "AI가 제안하는 감정"이고 새 카드는 "사용자가 확정하는 꿈의 구성요소"라 성격이 다르다. 새 구조화 출력 모델을 만들고 `create_diary` 입력도 그에 맞춰 바꾼다.
- **주의**: 나이트루틴 채팅에는 정보 카드가 없다. 모닝에만 적용된다.

### 6. 꿈·하루 상세의 탭 구성 — **확장**

- **필요**: 꿈 3탭(AI 요약 / 전문 보기 / AI 감정 인사이트), 하루 2탭(하루 보기 / AI 감정 인사이트). AI 요약 탭에는 **핵심 키워드 칩**과 **오늘의 조언**이 있다.
- **현재**: `DiaryGenerationResponse`는 `title`, `content`, `tags`(3개), `image_prompt`다. 키워드 칩은 `tags`로 덮이지만 **"오늘의 조언"에 해당하는 필드가 없다.**
- **판단**: **확장**. `tags`는 재활용하고 조언 필드를 추가한다. 단 `ChatRoom.tags`가 `VarChar(50)`이라 칩 5개를 담기엔 좁다 — 컬럼 확장 또는 정규화가 필요하다.

### 7. 장바구니 — **분리**

- **필요**: 담기 / 전체 선택 / 개별 삭제 / 전체 삭제 / 금액 합계 / 구매하기.
- **현재**: 없다. `Purchase.is_bought`가 `false`면 장바구니처럼 보이지만, `Purchase`는 `item_id` 1건에 `DiaryEntry`·`Shipment`·`Payment`가 매달린 **결제 단위**다.
- **판단**: **분리**. `is_bought=false`를 장바구니로 재활용하면 결제 전 상태의 `Purchase`에 배송·결제 레코드가 붙는 모호한 구조가 된다. 장바구니 전용 모델을 만든다.

### 8. 구매 / 결제 / 배송 — **신규(API만)**

- **현재**: 스키마는 완비(`Purchase`, `Payment`, `Shipment`, `UserAddress`)인데 엔드포인트가 0개다.
- **판단**: **신규**. 스키마는 그대로 쓰고 API 계층 전체를 새로 만든다. 실제 PG 연동 여부는 별도 결정이 필요하다.

### 9. Google 소셜 로그인 — **신규(API만)**

- **현재**: `UserSocialAccount`(provider, provider_user_id, `@@unique`) 테이블이 이미 있다. `AuthToken`(refresh_token, device_id, expires_at, revoked_at)도 있다. 하지만 `userApi`는 `signup`/`login` 2개뿐이고, `login`은 access token만 발급한다 — **refresh 토큰 발급·갱신 로직이 없다.**
- **판단**: **신규**. 스키마 변경 없이 OAuth 콜백 처리와 토큰 발급 API를 추가한다. 리프레시 흐름도 이때 같이 정리하는 게 낫다.

### 10. 상품 이미지 캐러셀 — **재활용(서비스 수정)**

- **현재**: `ItemImage`가 이미 1:N이고 `sort_order`도 있다. 그런데 `storeService`가 `item.ItemImage[0]` — **첫 장만 꺼낸다.**
- **판단**: **재활용**. 스키마도 쿼리도 그대로고, 서비스에서 리스트 전체를 `sort_order` 순으로 내려주도록 고치면 끝난다. 가장 싼 항목이다.

### 11. 상품 뱃지(인기상품 / 신상품) — **확장**

- **현재**: `Item`에 `headline`은 있으나 뱃지용 필드가 없다.
- **판단**: **확장**. 뱃지가 고정 표기면 컬럼 추가, 판매량 기반이면 `Purchase` 집계로 도출. 어느 쪽인지 결정 필요.

### 12. 검색 / 알림 — **신규**

- **검색**: 대시보드 상단 돋보기. `ChatRoom.content_vector`(pgvector 3072차원)가 이미 있어 유사도 검색 기반은 깔려 있으나 엔드포인트가 없다. 단순 제목 검색인지 의미 검색인지 결정 필요. **대응 화면이 Figma에 없다.**
- **알림**: 상단 벨. `NotificationLog`/`NotificationType`/`UserNotificationSetting`/`UserDevice.push_token` 전부 있으나 엔드포인트가 없다. **대응 화면이 Figma에 없다.**

### 13. 설정 탭 — **조사 불가**

하단탭 4번째가 `설정`인데 Figma에 화면이 없다. 현재 FE는 "아직 준비 중인 기능입니다! 🚀" 스낵바를 띄운다.

## 정리 — BE 작업 없이 가능한 화면

리디자인 화면 중 **BE를 건드리지 않고** 지금 바로 이관할 수 있는 것:

| 화면 | 비고 |
|---|---|
| 로그인 `104:446` | Google 버튼만 비활성 |
| 회원가입 `107:627` | 필드 구성이 `User` 스키마와 일치 |
| 홈 `516:783` `500:905` | Dream Calendar 위젯은 더미 |
| 스토어 목록 `509:560` `505:509` | |
| 상품 상세 `510:788` `514:428` | 캐러셀은 서비스 3줄 수정, 뱃지는 하드코딩 |
| 모닝 채팅 `476:548` | 정보 카드는 더미 |
| 나이트 채팅 `516:1114` | |

**BE부터 손대야 하는 화면**: 꿈/하루 대시보드(1·3번), 월간 캘린더(4번), 꿈/하루 상세 탭(2·6번), 장바구니(7번), 구매 흐름(8번).

## 남은 결정 사항

- 감정 집계를 **어떤 단위로 저장할지** (기록 1건당 감정 N개 점수 / 일별 집계 / 둘 다). 1·2·4번이 전부 여기 걸려 있다.
- 구매에 **실제 PG를 붙일지**, 아니면 데모 수준으로 둘지.
- 뱃지를 **고정 컬럼**으로 둘지 **판매량 집계**로 도출할지.
- 검색이 **제목 검색**인지 **벡터 의미 검색**인지.
- 설정 화면 범위.
