# 홍보용 웹페이지 설계 — 날씨 테마 + 꿈 해몽 데모

- 작성일: 2026-09-09
- 상태: 설계 확정, 구현 전
- 관련: [아키텍처 가이드](../00-overview/02-architecture.md), [ADR 0001](../40-decisions/0001-neon-to-supabase.md)

## 1. 목적과 범위

Flutter 앱과 별개로 운영하는 **정적 홍보 웹페이지**를 만든다. 방문자가 가입 없이 서비스를 맛보게 하고 앱 설치로 유도하는 것이 목적이다.

기능 3개:

1. **오늘 날씨 표시 + 날씨별 테마** — 방문자 위치 기반
2. **꿈 해몽 데모** — MORNING 루틴 해몽, IP당 2회
3. **오늘의 꿈 랭킹** — 데모 이용자들이 많이 꾼 꿈 카테고리 TOP 5

날씨와 해몽은 서로 독립이다. 날씨는 해몽 프롬프트에 들어가지 않는다. 해몽이 궁금해지는 시점(오전·출근길)에 오늘 날씨도 같이 보여주는 것이 의도다.

### 범위 밖

- 일기 생성, 이미지 생성(FLUX) — 비용 통제를 위해 데모에서 제외한다
- 멀티턴 대화 — 데모는 1턴이다
- 회원가입·로그인 — 데모는 완전 익명이다
- NIGHT 루틴 — 홍보 페이지는 MORNING만 쓴다

## 2. 전체 구조

```
방문자 브라우저 (WEB/, 정적 호스팅)
  │
  ├─ ipapi.co              → 도시명·좌표          (외부, 키 불필요)
  ├─ Open-Meteo            → 현재 날씨 WMO 코드   (외부, 키 불필요)
  │
  └─ Render BE (기존 서비스)
       ├─ POST /demo/interpret   → 해몽 (인증 없음, rate limit 있음)
       └─ GET  /demo/ranking     → 오늘의 꿈 TOP 5 (인증 없음)
```

**새 Render 웹 서비스를 만들지 않는다.** 홍보 페이지는 정적 파일이라 인스턴스 시간을 쓰지 않으므로 무료 750h 쿼터와 무관하다. BE는 기존 서비스를 그대로 쓴다.

저장소는 같은 레포의 `WEB/` 폴더다.

## 3. BE 변경

### 3.1 추가·수정 파일

| 파일 | 종류 | 내용 |
|---|---|---|
| `BE/app/api/demoApi.py` | 신규 | 라우터 2개 |
| `BE/app/services/demoService.py` | 신규 | rate limit, AI 호출, 카운트 집계 |
| `BE/app/repositories/demoRepository.py` | 신규 | `demo_dream_counts` upsert·조회 |
| `BE/app/schemas/demoSchema.py` | 신규 | 요청·응답 스키마 |
| `BE/app/main.py` | 수정 | `CORSMiddleware` 추가, 라우터 등록 |
| `BE/app/schemas/chatSchema.py` | 수정 | `AIAnalysisResponse`에 `dream_category` 추가 |
| `BE/app/core/ai/langchainManager.py` | 수정 | 두 프롬프트에 카테고리 지시 추가 |
| `BE/prisma/schema.prisma` | 수정 | `DemoDreamCount` 모델 추가 |

기존 4계층(api → services → repositories → db)을 그대로 따른다.

파일명은 단수형(`demoService.py`)으로 쓴다. `user*`만 복수형인 프로젝트 관례를 따른 것이다.

### 3.2 재사용하는 것

데모는 새 AI 로직을 만들지 않는다. 기존 자산을 그대로 호출한다.

- `analyze_dream_chat(history="", new_message=꿈, routine_type="MORNING")`
- `MORNING_CHAT_PROMPT` — 프롬프트 본문은 건드리지 않고 카테고리 지시만 덧붙인다
- `AIAnalysisResponse` — 응답 스키마 그대로

즉 실제로 재사용되는 것은 엔드포인트가 아니라 **프롬프트와 스키마**다. 기존 `/chatting/*`는 세션·소유권·DB 저장이 전제라 익명 방문자가 탈 수 없다.

### 3.3 엔드포인트

```
POST /demo/interpret
  요청:  { "dream": "..." }                    # 1~500자
  응답:  200 {
           "theme": "...",
           "vibe": "...",
           "suggested_feelings": ["...", "...", "..."],
           "ai_reply": "...",
           "remaining": 1                       # 이 IP의 남은 횟수
         }
         400 { "detail": "꿈 내용은 1~500자로 입력해 주세요." }
         429 { "detail": "...", "reason": "ip" | "global" }
         503 { "detail": "지금은 해몽을 불러올 수 없어요." }   # LLM 실패
```

```
GET /demo/ranking
  응답:  200 {
           "date": "2026-09-09",
           "items": [ { "rank": 1, "category": "뱀" }, ... ]   # 최대 5개
         }
```

**`dream_category`는 응답에 담지 않는다.** LLM이 뽑아 오지만 랭킹 집계에만 쓰고 방문자에게는 보여주지 않는다. `demoSchema.py`가 별도 응답 모델을 정의해 위 5개 필드만 내보낸다(`AIAnalysisResponse`를 그대로 반환하지 않는다).

**랭킹 응답에 횟수를 담지 않는다.** 초기에는 표본이 하루 수십 건이라 실제 횟수를 노출하면 홍보 페이지에서 빈약해 보인다. 순위만 주는 것은 거짓이 아니며, 데이터가 쌓인 뒤 횟수를 켜는 것은 응답에 필드를 더하는 것으로 끝난다.

`remaining`을 응답에 실어 프론트가 자체 카운팅을 하지 않게 한다. 남은 횟수의 진실은 서버에만 있고 프론트는 표시만 한다.

### 3.4 남용 방지

3중으로 막는다. 목적이 각각 다르다.

| 장치 | 값 | 막는 것 |
|---|---|---|
| 입력 길이 제한 | 1~500자 | 긴 텍스트를 붙여 넣어 토큰을 태우는 것 |
| IP당 횟수 | 2회/일 | 한 사람이 연타하는 것 |
| 전역 상한 | 200회/일 (환경변수) | 분산된 봇, 즉 지갑 |

- 카운터는 **프로세스 메모리 dict**다. Render 무료는 단일 인스턴스라 Redis가 필요 없다.
- 리셋은 KST 자정 기준이다. 요청 시각의 날짜와 저장된 날짜가 다르면 카운터를 비운다.
- **Render 재시작(재배포, 새벽 슬립) 시 카운터가 초기화된다.** 한계로 수용한다. 제한이 잠시 풀릴 뿐 데이터가 손실되지는 않는다. 랭킹은 DB에 있으므로 영향이 없다.
- 전역 상한 도달 시 `reason: "global"`로 응답한다. 프론트는 IP 소진과 같은 팝업을 띄우되 문구만 달리한다.

#### 방문자 IP 추출 — 구현 시 반드시 검증할 것

Render는 프록시 뒤에 있으므로 `request.client.host`는 방문자가 아니라 Render 내부 프록시 IP를 준다. 그대로 쓰면 **모든 방문자가 같은 IP로 집계되어 첫 두 명이 쿼터를 쓰고 나머지가 전원 차단된다.**

`X-Forwarded-For` 헤더에서 꺼내야 하는데, 이 헤더는 **클라이언트가 위조할 수 있다.** 방문자가 가짜 IP를 앞에 끼워 넣으면 IP 제한이 무한 우회된다.

따라서 구현 첫 단계는 **실제 Render 배포 환경에서 요청 헤더 전체를 로그로 찍어, Render가 실 IP를 리스트의 어느 위치에 넣는지 확인하는 것**이다. 추측으로 파싱하면 뚫린다. 확인 전까지는 전역 상한이 유일한 방어선이라고 간주한다.

### 3.5 CORS

`BE/app/main.py`에 `CORSMiddleware`를 추가한다. 현재 이 앱에는 CORS 설정이 없다. 지금까지 문제가 없던 이유는 Flutter 네이티브 앱에 동일 출처 정책이 적용되지 않기 때문이며, 브라우저에서 호출하는 순간 전부 차단된다.

- `allow_origins`는 `WEB_ORIGIN` 환경변수로 주입한다. 쉼표로 여러 개를 받는다.
- **`["*"]`를 쓰지 않는다.** 아무 사이트나 데모 엔드포인트를 임베드해 쿼터를 태울 수 있다.
- 로컬 개발용 출처는 환경변수에 함께 넣는다.
- `allow_credentials`는 켜지 않는다. 데모는 쿠키·인증을 쓰지 않는다.

### 3.6 꿈 카테고리

랭킹 집계를 위해 해몽 결과에서 카테고리 하나를 뽑는다.

**확정 목록 (13개)**

```
쫓김 · 이빨 · 똥 · 돼지 · 조상님 · 뱀 · 불 · 물 · 높은곳 · 피 · 시험 · 죽음 · 기타
```

앞의 10개는 `MORNING_CHAT_PROMPT`가 이미 핵심 상징 예시로 나열하고 있는 것들이다(`langchainManager.py:21`). 그대로 승격시켜 해몽 본문과 랭킹이 같은 어휘를 쓰게 한다.

추출은 **LLM이 한다.** `AIAnalysisResponse`에 필드를 추가한다:

```python
dream_category: str = Field(description="아래 목록 중 정확히 하나: 쫓김, 이빨, ...")
```

키워드 정규식 매칭도 가능하지만, 이미 LLM을 호출하고 있어 필드 하나를 더 받는 비용이 사실상 없고 정확도가 더 낫다.

**기존 앱에 미치는 영향**: `AIAnalysisResponse`는 앱의 `/chatting/message`도 쓰는 스키마다. 필드를 추가하면 앱 응답에도 `dream_category`가 실린다. FE는 모르는 필드를 무시하므로 동작에 영향은 없다. 다만 NIGHT 루틴에서도 이 필드가 채워져야 파싱이 깨지지 않으므로 `NIGHT_CHAT_PROMPT`에도 "해당 없으면 기타" 지시를 넣는다.

LLM이 목록 밖 값을 반환하면 서비스 계층에서 `기타`로 정규화한다.

### 3.7 DB 스키마

```prisma
model DemoDreamCount {
  demo_count_id BigInt   @id(map: "PK_DEMO_DREAM_COUNTS") @default(autoincrement())
  date          DateTime @db.Date
  category      String   @db.VarChar(20)
  count         Int      @default(0)

  @@unique([date, category], map: "UQ_DEMO_COUNT_DATE_CATEGORY")
  @@map("demo_dream_counts")
}
```

- 해몽 1회 = `(오늘, 카테고리)` upsert로 `count + 1`
- 조회 = 오늘 날짜 행을 `count` 내림차순 5개
- **일일 초기화 로직이 없다.** 날짜 컬럼으로 분리되므로 초기화가 저절로 된다. 자정 스케줄러도, 삭제 배치도 필요 없다.
- 용량: 하루 최대 13행, 1년에 약 4,700행. Supabase 0.5GB 제한에 무의미한 수준이다.
- 날짜 기준은 KST다. 서버가 UTC로 돌 수 있으므로 저장·조회 모두 KST로 변환한 날짜를 쓴다.

**저장하지 않는 것**: 꿈 원문, 해몽 결과, 방문자 IP, 세션. 데모는 개인 데이터를 남기지 않는다. 저장되는 것은 `(날짜, 카테고리, 횟수)` 세 값뿐이다.

앱 사용자의 꿈 데이터는 랭킹에 섞지 않는다. 개인 기록이고, `ChatRoom`에 카테고리 컬럼도 없다.

마이그레이션은 루트에서 실행한다:

```bash
prisma migrate deploy --schema=BE/prisma/schema.prisma
```

## 4. 웹 페이지

### 4.1 구성

```
WEB/
  index.html
  style.css
  app.js
```

빌드 도구 없음, 프레임워크 없음. 정적 파일 3개다. 페이지 하나에 기능 3개뿐이라 번들러를 들일 이유가 없다.

### 4.2 화면 흐름

```
페이지 로드
  ├─ ipapi.co 호출 → 도시명, 위도, 경도
  │    └─ Open-Meteo 호출 → WMO 날씨 코드
  │         └─ 테마 클래스 적용 + 날씨 위젯 표시
  ├─ GET /demo/ranking → 화면 하단에 TOP 5 표시
  └─ (대기)

사용자가 꿈 입력 → 버튼
  └─ POST /demo/interpret
       ├─ 200 → 해몽 결과 표시, remaining 갱신
       └─ 429 → 앱 유도 팝업
```

위치·랭킹 두 흐름은 서로 독립이며 병렬로 나간다. 하나가 실패해도 나머지는 진행된다.

### 4.3 날씨 테마

Open-Meteo의 WMO 코드를 5종으로 접는다.

| 테마 | WMO 코드 |
|---|---|
| 맑음 | 0, 1 |
| 흐림 | 2, 3 |
| 안개 | 45, 48 |
| 비 | 51~67, 80~82, 95~99 |
| 눈 | 71~77, 85, 86 |

`<body class="theme-rain">` 식으로 클래스만 갈아끼우고 색은 CSS 변수로 바꾼다. 색값은 [디자인 토큰](../30-design/01-design-tokens.md)을 따른다.

### 4.4 랭킹 표시

화면 하단에 "오늘 사람들이 많이 꾼 꿈" 섹션을 둔다. 순위와 카테고리 이름만 표시하고 횟수는 표시하지 않는다.

### 4.5 횟수 소진 팝업

`remaining: 0` 이거나 429 응답이면 팝업을 띄운다. 내용은 "앱에서 더 해보세요 / 추가 기회 무료 제공" 방향이며 앱 스토어 링크를 건다. 정확한 카피는 구현 단계에서 정한다.

## 5. 실패 처리

| 실패 지점 | 대응 |
|---|---|
| ipapi.co 실패·차단 | 서울 좌표로 폴백, 도시명은 표시하지 않음 |
| Open-Meteo 실패 | 기본 테마 유지, 날씨 위젯 숨김 |
| `/demo/ranking` 실패 | 랭킹 섹션 숨김 |
| BE 응답 지연 | 로딩 표시, 60초 타임아웃 |
| 429 | 앱 유도 팝업 |
| 400 | 입력창 아래 인라인 메시지 |
| 5xx / 타임아웃 | "잠시 후 다시 시도해 주세요" |

원칙: **날씨가 죽어도 해몽은 되고, 해몽이 죽어도 페이지는 뜬다.** 어떤 외부 호출이 실패해도 빈 화면이 나오지 않는다.

콜드 스타트는 크게 고려하지 않아도 된다. 기존 크론이 `/item/list`를 10분 간격으로 호출해 BE를 깨워 두고 있다([ADR 0001](../40-decisions/0001-neon-to-supabase.md)). 다만 크론이 쉬는 02:00–07:00 KST에는 첫 요청이 느릴 수 있으므로 타임아웃을 넉넉히 둔다.

## 6. 검증

이 프로젝트에는 테스트 프레임워크가 없다. 실제 실행으로 검증한다.

### BE

```bash
python -m py_compile BE/app/api/demoApi.py BE/app/services/demoService.py \
                     BE/app/repositories/demoRepository.py
```

로컬 uvicorn 기동 후:

| 확인 항목 | 합격 조건 |
|---|---|
| 정상 해몽 | `POST /demo/interpret` 200, 4개 필드 + `remaining: 1` |
| IP 제한 | 같은 IP 3회째 호출이 429, `reason: "ip"` |
| 길이 초과 | 501자 입력이 400 |
| 빈 입력 | 빈 문자열이 400 |
| 카테고리 정규화 | 목록 밖 값이 와도 DB에 `기타`로 저장 |
| 랭킹 집계 | 해몽 3회 후 `GET /demo/ranking`이 해당 카테고리 포함 |
| 랭킹 날짜 분리 | DB에 어제 날짜 행을 넣어도 오늘 응답에 안 나옴 |
| CORS | 허용 출처의 preflight 통과, 미허용 출처는 차단 |
| LLM 실패 | Gemini 키를 비우고 호출 시 503, 500이 아님 |
| 앱 회귀 | `POST /chatting/message`가 기존대로 동작 (스키마 필드 추가 영향 확인) |

전역 상한은 값을 1로 낮춘 뒤 2회 호출해 `reason: "global"`을 확인한다.

### 배포 후 1회성 확인

`X-Forwarded-For` 파싱이 맞는지 확인한다(3.4 참고). 서로 다른 네트워크 두 곳에서 접속해 각각 2회씩 해몽이 되는지 본다. 한쪽이 즉시 429면 IP 추출이 틀린 것이다.

### 웹

| 확인 항목 | 합격 조건 |
|---|---|
| 테마 5종 | 코드를 강제 주입해 5종 모두 렌더 확인 |
| 위치 폴백 | ipapi.co를 차단해도 페이지가 정상 표시 |
| 랭킹 표시 | 순위만 나오고 횟수는 없음 |
| 소진 팝업 | 3회째 시도에 팝업 |
| 모바일 | 출근길 사용이 주 시나리오이므로 모바일 폭 우선 확인 |

## 7. 환경변수 추가

| 이름 | 용도 | 예시 |
|---|---|---|
| `WEB_ORIGIN` | CORS 허용 출처(쉼표 구분) | `https://re-view.vercel.app,http://localhost:5500` |
| `DEMO_DAILY_GLOBAL_LIMIT` | 전역 일일 상한 | `200` |

Render 대시보드에 직접 입력한다(`render.yaml`은 `sync: false`).

## 8. 미정 사항

구현 단계에서 정한다. 설계에는 영향이 없다.

- 정적 호스팅 업체 — Vercel을 권장하나 확정 아님
- 페이지 카피, 비주얼, 앱 스토어 링크
- `DEMO_DAILY_GLOBAL_LIMIT` 최종값 — 200으로 시작해 사용량을 보고 조정
