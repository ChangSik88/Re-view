# 아키텍처 이해 가이드 — 왜 이렇게 생겼나

[온보딩 가이드](../20-engineering/01-onboarding.md)가 "무엇이 어디에 있고 어떻게 실행하는지"를 다룬다면, 이 문서는 **"왜 이런 구조를 골랐는지"**를 다룬다. 구조를 따라 하는 것과 이해하고 쓰는 것은 다르다 — 새 기능을 어느 층에 넣을지 고민될 때 이 문서로 돌아오면 된다.

## 1. 전체 그림

```
┌─────────────┐  HTTPS   ┌──────────────────┐  Prisma  ┌──────────────────┐
│ Flutter 앱  │ ───────> │ FastAPI (Render) │ ───────> │ Supabase (PG)    │
│ (안드로이드)│ <─────── │                  │          │  + pgvector      │
└─────────────┘   JSON   │   ┌ core/ai ─────┤          └──────────────────┘
                         │   │ Gemini: 해몽·일기·임베딩
                         │   │ FLUX:   꿈 이미지 생성
                         │   └──> Supabase Storage (이미지 공개 URL)
                         └──────────────────┘
```

앱·DB·스토리지 전부 **관리형 무료 티어**다. 학생 팀이 서버 운영(프로세스 관리, nginx, TLS 갱신)에 시간을 쓰지 않기 위한 선택이고, 그 대가로 슬립 제약이 있다(15분 유휴 시 Render 정지 — [README 배포 항목](../../README.md) 참고). 원래 AWS EC2에 직접 올렸다가 이 구성으로 이관했고, DB는 Neon을 거쳐 Supabase로 한 번 더 옮겼다([ADR 0002](../40-decisions/0001-neon-to-supabase.md)).

## 2. 백엔드 — 계층 구조(Layered Architecture)

라우터/서비스/리포지토리의 **3계층**에 인프라 계층(core)이 받치는 구조다. 요청은 항상 한 방향으로만 흐른다:

```
api (라우터)  →  services (비즈니스 로직)  →  repositories (쿼리)  →  core/db (Prisma)
```

| 층 | 담당 | 하면 안 되는 것 |
|---|---|---|
| `api/` | HTTP만: 요청 파싱, 인증 주입, 예외 → 상태코드 변환 | 비즈니스 로직 |
| `services/` | 진짜 로직: 여러 repo 조합, 소유권 검증, AI 호출 지시 | HTTP 지식(상태코드, HTTPException) |
| `repositories/` | Prisma 쿼리만 | 로직, 데이터 가공 |
| `core/` | 전역 인프라: DB 클라이언트, JWT/해싱, AI 래퍼, 스토리지 | 도메인 지식 |

### 왜 나눴나

1. **바꾸는 이유가 다른 코드를 분리한다.** "응답 필드 하나 추가"는 api/schemas만, "해몽 규칙 변경"은 services만, "쿼리 최적화"는 repositories만 건드린다. 수정 반경이 예측 가능해진다.
2. **보안 로직의 위치가 고정된다.** "누구인지"(인증)는 api 층의 `Depends(get_current_user_id)`가, "이 데이터가 그 사람 것인지"(소유권)는 서비스 층의 `_get_owned_session`이 담당한다. 이게 흩어져 있으면 엔드포인트 하나 추가할 때마다 구멍이 날 수 있다.
3. **새 기능이 패턴 복붙이 된다.** 5개 도메인(chat, chatSession, report, store, user)이 전부 같은 모양이라, 기존 도메인 하나를 따라 치면 새 도메인이 만들어진다. 온보딩 속도가 여기서 나온다.
4. **나중에 테스트를 붙일 수 있다.** 서비스는 HTTP를 모르므로, 테스트 프레임워크를 도입하면 서버 기동 없이 서비스 함수만 단위 테스트할 수 있다(아직 테스트는 없다).

의존은 위→아래 단방향만 허용한다. 알려진 위반 사례가 하나 있다: `userServices.py`가 서비스 층에서 `HTTPException`을 직접 던진다. 다른 도메인처럼 `ValueError`/`PermissionError`를 던지고 api 층에서 변환하는 게 맞다 — 새 코드는 이 위반을 따라 하지 말 것.

### 실제 요청 하나 따라가기: `POST /chatting/diary` (일기 생성)

이 프로젝트에서 제일 많은 층을 관통하는 요청이다. 이 흐름 하나를 이해하면 구조 전체가 보인다.

1. **api** — `chatApi.py:30` `generate_diary`. JWT에서 `user_id`를 뽑아 주입받고(`Depends(get_current_user_id)`), 서비스를 호출하고, `ValueError`→404, `PermissionError`→403 변환만 한다. 로직 없음.
2. **services** — `chatService.create_diary`. 순서대로: 소유권 검증(`_get_owned_session`) → 대화 이력 조회 → Gemini로 일기 생성(`generate_diary_content`) → 제목+내용 임베딩 생성 → 길이 방어(`title[:50]` — DB 컬럼이 VarChar(50)이라 넘치면 트랜잭션이 터진다) → 저장 지시.
3. **repositories** — `chatRepository.update_session_with_diary`. 일기 텍스트 저장과 벡터 갱신을 **`db.tx()` 한 트랜잭션**으로 묶는다. 벡터는 Prisma가 `vector` 타입을 지원하지 않아 `execute_raw`로 넣는다.
4. **다시 services** — `_generate_and_save_image`. 이미지 생성·업로드는 **트랜잭션 밖**이고 예외를 삼킨다(실패 시 `image_url: None`).

왜 이미지만 밖인가: 외부 이미지 API(FLUX)는 실패 확률이 높은 의존성이다. **핵심 데이터(일기)와 부가물(그림)의 실패를 격리**해서, 그림이 안 나와도 일기는 저장되게 한 의도적 설계다. 반대로 텍스트와 벡터는 한쪽만 저장되면 안 되므로(검색이 깨진 일기가 생김) 트랜잭션으로 묶었다.

### core/ai — AI를 함수 뒤로 숨기기

서비스는 `analyze_dream_chat(...)`처럼 **함수를 호출할 뿐**, 그 안이 Gemini인지 LangChain인지 모른다. 모델 교체·프롬프트 수정이 서비스 코드에 번지지 않게 하는 캡슐화다.

- `langchainManager.py` — 해몽 대화, 일기 생성, 임베딩
- `reportManager.py` — 경향 분석
- `imageManager.py` — FLUX 이미지 생성

두 가지를 꼭 알아야 한다:

- **`routine_type` 분기**: 거의 모든 AI 흐름이 `"MORNING"`(전통 해몽)/`"NIGHT"`(하루 회고)로 프롬프트를 갈아끼운다. 프롬프트를 고치면 반드시 두 갈래를 다 확인한다.
- **LLM은 무상태다**: 모델은 이전 대화를 기억하지 않는다. 그래서 `process_message`가 매 턴 DB에서 전체 이력을 꺼내 문자열로 이어붙여 다시 보낸다. 즉 **대화의 "기억"은 우리 DB(`chat_messages`)에 있고, 모델에는 매번 통째로 재주입**하는 구조다. (지금은 전체를 다 보내서 대화가 길수록 비용이 늘어난다 — 최근 N개 윈도잉이 예정된 개선.)

### schemas — 입출력 계약

Pydantic 모델이 요청 검증과 응답 직렬화를 담당한다. **DB 모델과 API 응답 모델을 분리**하는 이유: DB에는 있지만 밖으로 나가면 안 되는 필드가 있기 때문이다. 실제로 회원가입 응답에 `password`가 노출됐다가 스키마로 막은 이력이 있다(#31). 응답에 뭘 내보낼지는 항상 schemas에서 명시적으로 정한다.

## 3. DB — Prisma + pgvector

- **왜 Prisma**: `prisma/schema.prisma` 파일 하나가 테이블 구조의 진실원이고, 마이그레이션 SQL을 자동 생성한다. 스키마 변경 절차: 파일 수정 → `prisma generate`(클라이언트 재생성) → 루트에서 `prisma migrate deploy --schema=BE/prisma/schema.prisma`(실 DB 반영).
- **스키마가 코드보다 앞서 있다**: 24개 모델 중 실제 코드가 쓰는 건 8개다. 나머지 16개(구매·결제·알림·소셜 로그인 등)는 미래를 위해 선설계된 상태다. **스키마에 있다고 구현된 게 아니다** — 기능 유무는 `api/` 라우터 기준으로 판단할 것.
- **`content_vector`(pgvector)**: 3072차원이라 Prisma ORM이 못 다뤄 `execute_raw`로만 접근한다. 벡터 인덱스는 pgvector의 2000차원 한계 때문에 의도적으로 보류 중이다(해법 후보는 `migration.sql` 끝의 주석에 적어 뒀다: `halfvec` 캐스팅).

## 4. 프론트엔드 — Flutter 구조

```
lib/
├── main.dart      # 진입점 + 이름 기반 라우팅 테이블
├── config/        # Api 클래스: 모든 엔드포인트 경로 문자열의 유일한 정의처
├── services/      # 도메인별 API 래퍼 (auth/chat/session/report/store) + ApiClient
├── models/        # 데이터 모델
├── theme/         # AppColors/AppTextStyles 토큰 (정의만, 화면 적용은 진행 중)
└── screens/       # 화면 — 기능별 폴더 (auth/home/chat/dream/store)
```

핵심 규칙 하나로 요약된다: **화면은 HTTP를 모른다.** 화면 → `XService` → `ApiClient` 순서로만 통신한다.

- `ApiClient`(`services/api_client.dart`)가 **유일한 HTTP 관문**: baseUrl 결합, JWT 헤더 자동 주입, utf8→JSON 디코드, 실패는 `ApiException`으로 통일.
- `Api`(`config/api.dart`)에 경로 문자열을 전부 모은다. 화면이나 서비스에 URL을 직접 쓰지 않는다.
- 왜: 주소·토큰·에러 처리의 수정 지점이 한 곳이 된다. EC2 → Render 이관 때 FE에서 실질적으로 baseUrl 한 곳만 바꾸면 됐던 게 이 구조 덕이다.

FE 서비스와 BE 라우터는 **1:1 대칭**이다. BE에서 어떤 엔드포인트를 고치면 FE의 어느 파일을 봐야 하는지 바로 나온다:

| FE (`lib/services/`) | BE (`app/api/`) |
|---|---|
| `auth_service.dart` | `userApi.py` |
| `chat_service.dart` | `chatApi.py` |
| `session_service.dart` | `chatSessionApi.py` |
| `report_service.dart` | `reportApi.py` |
| `store_service.dart` | `storeApi.py` |

상태관리는 전부 `setState`다. 화면 9개 규모에는 충분하다는 판단이고, `provider`는 pubspec에 선언만 돼 있고 실제 사용은 0곳이다(도입할지 제거할지 미결). 화면 작성 패턴(라우트 arguments, `mounted` 가드, 에러 폴백 규칙)은 [FE 컨벤션](../20-engineering/03-frontend.md)에 있다.

## 5. 인증 흐름 — "누구인지"와 "그 사람 것인지"는 다른 문제

```
로그인 → BE가 JWT 발급(7일) → FE가 저장 → 매 요청 Authorization: Bearer 헤더
      → BE dependencies.get_current_user_id가 토큰에서 user_id 추출 → 라우터에 주입
      → 서비스가 소유권 검증 (session.user_id == user_id)
```

검증이 두 단계인 이유: 토큰은 "이 요청이 누구인지"만 증명한다. "이 채팅방이 그 사람 것인지"는 데이터를 봐야 아는 문제라서 서비스 층(`_get_owned_session`)이 담당한다. **보호가 필요한 엔드포인트는 반드시 `Depends(get_current_user_id)`를 걸고, 특정 리소스를 만지는 로직은 반드시 소유권 검증을 거친다** — 이 두 줄이 이 프로젝트 보안의 전부다.

비밀번호는 bcrypt 해시로만 저장한다(`core/security.py`). 평문 저장 금지.

## 6. 더 읽을거리

- [온보딩 가이드](../20-engineering/01-onboarding.md) — 설치·실행·진행 이력
- [FE 컨벤션](../20-engineering/03-frontend.md) — FE 코드 작성 패턴
- [디자인 토큰](../30-design/01-design-tokens.md) — FE 색·타이포 실측값
- [CLAUDE.md](../../CLAUDE.md) — 명령어·주의사항 압축본
- [`40-decisions/`](../40-decisions/) — 구조·인프라 결정 기록(ADR)
- [`50-specs/`](../50-specs/) — 주요 변경의 설계 문서
