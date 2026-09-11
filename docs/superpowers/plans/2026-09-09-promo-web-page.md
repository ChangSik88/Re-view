# 홍보용 웹페이지(날씨 테마 + 해몽 데모 + 랭킹) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인증 없는 1턴 꿈 해몽 데모(`POST /demo/interpret`)와 오늘의 꿈 랭킹(`GET /demo/ranking`, 상한 없는 "전체보기")을 기존 Render BE에 추가하고, 이를 소비하는 정적 홍보 웹페이지(`WEB/`)를 만든다.

**변경 이력:** 최초 작성 후 `드림다이어리-디자인` 세션의 화면 설계 확인 결과를 반영해 갱신함 — "전체보기"는 별도 API·별도 테이블이 필요 없는 기존 랭킹 쿼리의 상한 해제였고(자세한 내용은 각 태스크 참고), 대신 `POST /demo/interpret` 응답에 `dream_category`를 새로 노출하기로 결정함(사용자 확인 완료, 기존 3.3 "방문자에게 비공개" 결정을 뒤집음 — "내가 해몽한 꿈" 표시에 필요).

**Architecture:** 기존 BE의 4계층(api → services → repositories → db)을 그대로 따르는 `demo` 도메인을 신설한다. AI 로직은 새로 만들지 않고 기존 `analyze_dream_chat`(MORNING)·`AIAnalysisResponse`를 재사용하며, 응답은 5개 필드만 노출하는 별도 스키마로 감싼다. `WEB/`은 빌드 도구 없는 정적 파일 3개(`index.html`/`style.css`/`app.js`)로, 브라우저에서 직접 BE와 외부 날씨 API를 호출한다.

**Tech Stack:** FastAPI, Prisma(PostgreSQL), LangChain(Gemini), 순수 HTML/CSS/JS(프레임워크 없음).

**참고 스펙:** `docs/50-specs/2026-09-09-promo-web-page-design.md` (섹션 번호는 이 문서 기준)

## Global Constraints

- 이 프로젝트에는 테스트 프레임워크가 없다. 각 태스크의 "테스트" 단계는 pytest가 아니라 `python -m py_compile`, `uvicorn` 로컬 기동 + `curl` 실행 결과로 대체한다(레포 CLAUDE.md 컨벤션).
- 4계층(api → services → repositories → db)을 반드시 따른다. 서비스 계층에서만 비즈니스 로직·소유권 검증을 수행한다(데모는 소유권 검증이 없다 — 인증 자체가 없음).
- 파일명은 단수형(`demoService.py`, `demoRepository.py`, `demoApi.py`, `demoSchema.py`)으로 쓴다. `user*`만 예외적으로 복수형인 것이 이 레포 컨벤션이다.
- CORS `allow_origins`에 `["*"]`를 절대 쓰지 않는다. `WEB_ORIGIN` 환경변수(쉼표 구분)만 허용하고 `allow_credentials`는 켜지 않는다.
- 데모는 개인 데이터를 저장하지 않는다: 꿈 원문, 해몽 결과, 방문자 IP, 세션 중 어느 것도 DB에 남기지 않는다. 저장되는 것은 `(날짜, 카테고리, 횟수)` 뿐이다.
- 날짜 계산은 전부 KST 기준이다(서버가 UTC로 돌 수 있음).
- Prisma 스키마를 고치면 `PYTHONUTF8=1 prisma migrate dev --name <이름> --schema=BE/prisma/schema.prisma`로 마이그레이션 파일을 만들고(로컬 DB 기준), 그 파일을 커밋한다. 운영 반영은 배포가 한다(`render.yaml`의 `buildCommand`에 `migrate deploy`가 들어 있다). **`migrate deploy`는 파일을 만들지 않는다** — Task 1에서 이걸로 한 번 헛돌았다.
- **`@db.Date` 컬럼에는 `datetime.date`를 넘기면 안 된다.** Prisma Python이 직렬화하지 못해 `TypeError: Type <class 'datetime.date'> not serializable`로 터진다. naive `datetime`(자정)으로 변환해 넘긴다. tz-aware를 넘기면 UTC 변환으로 날짜가 하루 밀릴 수 있다. (로컬 DB 실측 확인 완료)
- **`ZoneInfo("Asia/Seoul")`을 쓰지 않는다.** Windows에 IANA tz DB가 없어 로컬에서 `ZoneInfoNotFoundError`로 실패한다(Render는 Linux라 동작 — 로컬에서만 깨지는 형태). 한국은 DST가 없으므로 `timezone(timedelta(hours=9))` 고정 오프셋을 쓴다.
- `AIAnalysisResponse`는 앱의 `/chatting/message`도 쓰는 공유 스키마다. 필드를 추가한 뒤에는 반드시 그 엔드포인트가 기존대로 동작하는지 확인한다.
- 카테고리 총 개수는 아직 미확정(현재 13종 확정 아님, "100종 규모" 예시가 나온 상태)이다. 이 계획은 현재 13종 목록(스펙 3.6)으로 구현하고, 최종 목록이 나오면 Task 2의 `CATEGORY_LIST`·프롬프트 문구와 Task 7의 FE 카테고리 사전만 다시 고치면 된다.
- "전체보기" 화면의 검색창(카테고리 검색)은 카테고리 총 개수가 확정될 때까지 보류한다 — 디자인 세션 판단: 13종 수준이면 장식에 가까워 빼는 게 낫고, 100종 규모면 필요하다. 이번 구현(Task 7)에는 포함하지 않는다.

---

## Task 1: Prisma 스키마 — DemoDreamCount 모델 추가

**Files:**
- Modify: `BE/prisma/schema.prisma`

**Interfaces:**
- Produces: Prisma 모델 `DemoDreamCount`(필드 `demo_count_id, date, category, count`), 컴파운드 unique 키(Prisma 클라이언트에서의 기본 이름은 `date_category` — Step 2에서 실제 생성 결과로 검증한다). Task 4(repository)가 이 이름에 의존한다.

- [ ] **Step 1: 모델 추가**

`BE/prisma/schema.prisma`의 `DiaryEntry` 모델과 `Item` 모델 사이(알파벳 순서 컨벤션 유지)에 추가:

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

- [ ] **Step 2: 클라이언트 재생성 및 컴파운드 키 이름 검증**

```bash
cd BE
PYTHONUTF8=1 prisma generate
```

생성 후 아래로 실제 필드명을 확인한다(Prisma Python은 `@@unique([a, b])`를 기본적으로 `a_b`로 노출한다):

```bash
python -c "import re,glob; f=[p for p in glob.glob('.venv/**/prisma/**/*.py', recursive=True)+glob.glob('../venv/**/prisma/**/*.py', recursive=True) if 'demodreamcount' in p.lower()]; print(f)"
grep -r "date_category" ../venv/Lib/site-packages/prisma/ 2>/dev/null | head -5
```

`date_category`가 아닌 다른 이름이 나오면 Task 4의 `where={"date_category": ...}` 부분을 그 이름으로 바꾼다.

- [ ] **Step 3: 마이그레이션 파일 생성 및 적용**

루트에서. `migrate deploy`가 아니라 `migrate dev`다 — deploy는 기존 파일을 적용만 할 뿐 파일을 만들지 않는다. `PYTHONUTF8=1`이 없으면 뒤이어 자동 실행되는 generate가 cp949로 깨진다.

```bash
PYTHONUTF8=1 prisma migrate dev --name add_demo_dream_count --schema=BE/prisma/schema.prisma
```

`BE/prisma/migrations/<타임스탬프>_add_demo_dream_count/migration.sql`이 생성되고 로컬 DB에 적용된다. 운영(Supabase) 반영은 배포가 한다(`render.yaml`의 `buildCommand`).

예상: `demo_dream_counts` 테이블 생성 로그.

- [ ] **Step 4: Commit**

```bash
git add BE/prisma/schema.prisma BE/prisma/migrations/
git commit -m "feat: DemoDreamCount 모델 추가 (홍보 웹페이지 랭킹 집계용)"
```

---

## Task 2: dream_category 필드 추가 (스키마 + 프롬프트)

**Files:**
- Modify: `BE/app/schemas/chatSchema.py`
- Modify: `BE/app/core/ai/langchainManager.py`

**Interfaces:**
- Produces: `AIAnalysisResponse.dream_category: str`. Task 5(demoService)가 이 필드를 읽어 랭킹 카테고리로 쓴다.

- [ ] **Step 1: AIAnalysisResponse에 필드 추가**

`BE/app/schemas/chatSchema.py`의 `AIAnalysisResponse`를 수정:

```python
class AIAnalysisResponse(BaseModel):
    theme: str = Field(description="꿈의 핵심 주제")
    vibe: str = Field(description="꿈의 전반적인 분위기")
    #동적 생성. 핵심 감정 키워드 3개를 대화에서 추출
    suggested_feelings: List[str] = Field(description="유저가 느꼈을 법한 핵심 감정 키워드 3개")
    ai_reply: str = Field(description="유저에게 건네는 AI의 공감 멘트 및 다음 질문")
    # 기본값을 둔 이유: 이 스키마는 운영 중인 /chatting/message도 공유한다.
    # 필수로 두면 LLM이 이 필드를 빠뜨리는 순간 파싱이 실패해 앱 채팅까지 죽는다.
    dream_category: str = Field(default="기타", description="아래 목록 중 정확히 하나: 쫓김, 이빨, 똥, 돼지, 조상님, 뱀, 불, 물, 높은곳, 피, 시험, 죽음, 기타")
```

**기본값은 스펙 3.6에서 벗어난 부분이다**(스펙엔 기본값이 없다). 리뷰 지적 후 사용자 확인을 거쳐 변경했다. 실패 모드가 비대칭이라서다 — 필수로 두면 LLM 누락 시 운영 중인 앱 채팅이 500으로 죽고, 기본값을 두면 랭킹 1건이 "기타"로 잡힐 뿐이다. 기본값 추가 전후로 MORNING(목록 내/목록 밖)·NIGHT 3케이스를 실제 LLM에 태워 동작이 같은 것을 확인했다.

- [ ] **Step 2: MORNING_CHAT_PROMPT에 카테고리 지시 추가**

`BE/app/core/ai/langchainManager.py`의 `MORNING_CHAT_PROMPT` 문자열에서 `반드시 아래 JSON 형식으로만 답하세요.` 줄 바로 앞에 추가:

```python
[카테고리 분류]
dream_category 필드에는 이 꿈과 가장 관련 깊은 것을 아래 목록 중 정확히 하나만 골라 담으세요: 쫓김, 이빨, 똥, 돼지, 조상님, 뱀, 불, 물, 높은곳, 피, 시험, 죽음, 기타. 해당하는 것이 없으면 반드시 "기타"로 답하세요.

반드시 아래 JSON 형식으로만 답하세요. 다른 설명은 추가하지 마세요.
{format_instructions}"""
```

(마지막 줄의 `{format_instructions}"""`는 기존 문자열 종료 부분이므로, 새 지시문을 그 앞 줄에 삽입하는 형태로 교체한다.)

- [ ] **Step 3: NIGHT_CHAT_PROMPT에도 동일 지시 추가**

`NIGHT_CHAT_PROMPT`에도 같은 방식으로 삽입하되, 밤 루틴은 카테고리 목적이 없으므로 문구를 다르게 한다:

```python
[카테고리 분류]
dream_category 필드는 랭킹 집계용 내부 필드입니다. 하루 회고 루틴에서는 해당하는 상징이 없는 경우가 대부분이므로, 아래 목록 중 명확히 일치하는 것이 없으면 반드시 "기타"로 답하세요: 쫓김, 이빨, 똥, 돼지, 조상님, 뱀, 불, 물, 높은곳, 피, 시험, 죽음, 기타.

반드시 아래 JSON 형식으로만 답하세요.
{format_instructions}"""
```

- [ ] **Step 4: 검증**

```bash
cd BE
python -m py_compile app/schemas/chatSchema.py app/core/ai/langchainManager.py
```

`uvicorn app.main:app --reload` 기동 후, 기존 앱 플로우로 `POST /chatting/message`를 호출해 응답에 `dream_category` 필드가 추가로 실려도 다른 필드가 깨지지 않는지 확인한다(로그인 → 세션 생성 → 메시지 전송 순서, 기존 `userApi`/`chatSessionApi`로 토큰과 세션을 먼저 발급받아야 함).

- [ ] **Step 5: Commit**

```bash
git add BE/app/schemas/chatSchema.py BE/app/core/ai/langchainManager.py
git commit -m "feat: AIAnalysisResponse에 dream_category 필드 추가 (아침/밤 프롬프트 반영)"
```

---

## Task 3: demoSchema.py — 요청/응답 스키마

**Files:**
- Create: `BE/app/schemas/demoSchema.py`

**Interfaces:**
- Produces: `DemoInterpretRequest(dream: str)`, `DemoInterpretResponse(theme, vibe, suggested_feelings, ai_reply, remaining, dream_category)`, `DemoRankingItem(rank, category)`, `DemoRankingResponse(date, items)`. Task 5(service)·Task 6(api)이 이 타입들을 그대로 쓴다.

- [ ] **Step 1: 스키마 작성**

```python
from pydantic import BaseModel
from typing import List


class DemoInterpretRequest(BaseModel):
    dream: str


class DemoInterpretResponse(BaseModel):
    theme: str
    vibe: str
    suggested_feelings: List[str]
    ai_reply: str
    remaining: int
    dream_category: str  # "내가 해몽한 꿈" 표시용. 정규화된 값(목록 밖이면 "기타")을 그대로 노출한다.


class DemoRankingItem(BaseModel):
    rank: int
    category: str


class DemoRankingResponse(BaseModel):
    date: str
    items: List[DemoRankingItem]  # 상한 없음. 그날 1건 이상 집계된 카테고리만 전부 담긴다.
```

**변경 이력 메모(원래 계획 대비):** 최초안은 `dream_category`를 응답에서 뺐다(스펙 3.3의 "방문자에게 비공개" 결정). "내가 해몽한 꿈" 표시 기능 때문에 뒤집혔다 — 사용자 확인 완료.

`dream` 길이 제한(1~500자)은 Pydantic `Field(min_length=..., max_length=...)`로 걸지 않는다. 그렇게 하면 FastAPI가 422를 반환하는데, 스펙(3.3)은 400을 요구한다. 길이 검증은 Task 5의 서비스 계층에서 수행해 `ValueError`로 올리고, Task 6의 API 계층에서 그 메시지를 그대로 400으로 반환한다(기존 `ChatService`의 `ValueError`→404 패턴과 동일한 방식).

- [ ] **Step 2: 검증**

```bash
cd BE
python -m py_compile app/schemas/demoSchema.py
```

- [ ] **Step 3: Commit**

```bash
git add BE/app/schemas/demoSchema.py
git commit -m "feat: 데모 API 요청/응답 스키마 추가"
```

---

## Task 4: demoRepository.py — DB 접근

**Files:**
- Create: `BE/app/repositories/demoRepository.py`

**Interfaces:**
- Consumes: Task 1에서 확정한 Prisma 컴파운드 unique 필드명(기본 가정 `date_category`).
- Produces: `DemoRepository.increment_category_count(target_date: date, category: str) -> None`, `DemoRepository.get_today_ranking(target_date: date) -> list`. Task 5(service)가 이 두 메서드를 호출한다.

- [ ] **Step 1: 작성**

`target_date`는 `datetime.date`가 아니라 **naive `datetime`(자정)**이다. Prisma Python이 `date`를 직렬화하지 못한다(Global Constraints 참고). 변환은 Task 5의 `_today_kst()`가 담당한다.

```python
from datetime import datetime
from app.core.db import db


class DemoRepository:
    # (오늘, 카테고리) 조합이 있으면 count+1, 없으면 새로 만든다.
    async def increment_category_count(self, target_date: datetime, category: str) -> None:
        await db.demodreamcount.upsert(
            where={"date_category": {"date": target_date, "category": category}},
            data={
                "create": {"date": target_date, "category": category, "count": 1},
                "update": {"count": {"increment": 1}},
            },
        )

    # "전체보기": 오늘 1건 이상 집계된 카테고리 전부, count 내림차순.
    # 동률은 카테고리 이름 가나다순(사용자 확정 규칙) — 상한(take)을 두지 않는다.
    async def get_today_ranking(self, target_date: datetime):
        return await db.demodreamcount.find_many(
            where={"date": target_date},
            order=[{"count": "desc"}, {"category": "asc"}],
        )
```

위 `upsert`/`find_many` 호출(컴파운드 키 `date_category`, `increment`, 2단 정렬)은 로컬 DB에 실제로 날려 동작을 확인했다 — KST 날짜가 밀리지 않고 그대로 저장되는 것까지 확인 완료.

**변경 이력 메모:** 최초안은 `take=limit`(기본 5)로 TOP 5만 뽑았다. 디자인 세션 확인 결과 "전체보기"는 그 상한을 없앤 것뿐 — 별도 API·별도 누적 테이블 불필요, `DemoDreamCount`와 이 쿼리 그대로 쓴다. 동률 시 가나다순 정렬은 이번에 추가된 규칙이다.

- [ ] **Step 2: 검증**

```bash
cd BE
python -m py_compile app/repositories/demoRepository.py
```

로컬 uvicorn 기동 후 아래 일회성 스크립트로 upsert/조회가 실제로 동작하는지 확인(CLAUDE.md 검증 컨벤션):

```python
# BE/scratch_check_demo_repo.py (검증 후 삭제)
import asyncio
from datetime import datetime, time
from dotenv import load_dotenv
load_dotenv()
from app.core.db import db
from app.repositories.demoRepository import DemoRepository

async def main():
    await db.connect()
    repo = DemoRepository()
    today = datetime.combine(datetime.now().date(), time.min)  # naive datetime(자정)
    await repo.increment_category_count(today, "뱀")
    await repo.increment_category_count(today, "뱀")
    rows = await repo.get_today_ranking(today)
    print([(r.category, r.count) for r in rows])
    await db.disconnect()

asyncio.run(main())
```

실행: `cd BE && python scratch_check_demo_repo.py` → `[("뱀", 2)]` 형태 출력 확인 후 파일 삭제.

- [ ] **Step 3: Commit**

```bash
git add BE/app/repositories/demoRepository.py
git commit -m "feat: 데모 랭킹 집계 repository 추가"
```

---

## Task 5: demoService.py — 남용 방지 + AI 연동 + 카테고리 정규화

**Files:**
- Create: `BE/app/services/demoService.py`

**Interfaces:**
- Consumes: `DemoRepository`(Task 4), `analyze_dream_chat`(기존 `langchainManager.py`), `AIAnalysisResponse.dream_category`(Task 2), `DemoInterpretResponse`/`DemoRankingResponse`/`DemoRankingItem`(Task 3).
- Produces: `DemoService.interpret(dream: str, client_ip: str) -> DemoInterpretResponse`(실패 시 `ValueError`/`DemoRateLimitError`/`DemoUnavailableError`), `DemoService.get_ranking() -> DemoRankingResponse`, 예외 클래스 `DemoRateLimitError(reason: str)`·`DemoUnavailableError`. Task 6(api)이 이 시그니처와 예외를 그대로 처리한다.

- [ ] **Step 1: 작성**

```python
import os
from datetime import date, datetime, time, timedelta, timezone
from typing import Dict, Tuple

from app.repositories.demoRepository import DemoRepository
from app.core.ai.langchainManager import analyze_dream_chat
from app.schemas.demoSchema import DemoInterpretResponse, DemoRankingResponse, DemoRankingItem

# 한국은 DST가 없어 고정 오프셋으로 충분하다.
# ZoneInfo("Asia/Seoul")은 Windows에 IANA tz DB가 없어 로컬 개발 시 실패한다.
KST = timezone(timedelta(hours=9))
IP_DAILY_LIMIT = 2
CATEGORY_LIST = [
    "쫓김", "이빨", "똥", "돼지", "조상님", "뱀", "불", "물", "높은곳", "피", "시험", "죽음", "기타",
]


class DemoRateLimitError(Exception):
    def __init__(self, reason: str):
        self.reason = reason


class DemoUnavailableError(Exception):
    pass


def _today_kst() -> date:
    """카운터 키·비교용 KST 날짜(메모리 안에서만 쓴다)."""
    return datetime.now(KST).date()


def _today_kst_for_db() -> datetime:
    """DB의 @db.Date 컬럼에 넘길 값. Prisma Python이 date를 직렬화하지 못해
    naive datetime(자정)으로 변환한다. tz-aware면 UTC 변환으로 날짜가 밀린다."""
    return datetime.combine(_today_kst(), time.min)


class DemoService:
    def __init__(self):
        self.demo_repo = DemoRepository()
        # 프로세스 메모리 카운터. Render 무료는 단일 인스턴스라 Redis 불필요.
        # 재배포·슬립 재시작 시 초기화되는 것은 허용된 한계(스펙 3.4).
        self._ip_counts: Dict[str, Tuple[date, int]] = {}
        self._global_count: Tuple[date, int] = (_today_kst(), 0)
        self._global_limit = int(os.getenv("DEMO_DAILY_GLOBAL_LIMIT", "200"))

    def _get_ip_count(self, client_ip: str) -> int:
        today = _today_kst()
        last_date, count = self._ip_counts.get(client_ip, (today, 0))
        return count if last_date == today else 0

    def _get_global_count(self) -> int:
        today = _today_kst()
        last_date, count = self._global_count
        return count if last_date == today else 0

    def _increment_ip(self, client_ip: str) -> int:
        today = _today_kst()
        new_count = self._get_ip_count(client_ip) + 1
        self._ip_counts[client_ip] = (today, new_count)
        return new_count

    def _increment_global(self) -> None:
        today = _today_kst()
        self._global_count = (today, self._get_global_count() + 1)

    async def interpret(self, dream: str, client_ip: str) -> DemoInterpretResponse:
        if not (1 <= len(dream) <= 500):
            raise ValueError("꿈 내용은 1~500자로 입력해 주세요.")

        # 두 제한 모두 증가 없이 먼저 확인한다. 하나라도 거부되면 카운터를 건드리지 않는다.
        if self._get_ip_count(client_ip) >= IP_DAILY_LIMIT:
            raise DemoRateLimitError("ip")
        if self._get_global_count() >= self._global_limit:
            raise DemoRateLimitError("global")

        try:
            ai_result = await analyze_dream_chat(history="", new_message=dream, routine_type="MORNING")
        except Exception as e:
            print(f"데모 해몽 LLM 호출 실패: {e}")
            raise DemoUnavailableError()

        new_ip_count = self._increment_ip(client_ip)
        self._increment_global()

        category = ai_result.dream_category if ai_result.dream_category in CATEGORY_LIST else "기타"
        await self.demo_repo.increment_category_count(_today_kst_for_db(), category)

        return DemoInterpretResponse(
            theme=ai_result.theme,
            vibe=ai_result.vibe,
            suggested_feelings=ai_result.suggested_feelings,
            ai_reply=ai_result.ai_reply,
            remaining=IP_DAILY_LIMIT - new_ip_count,
            dream_category=category,  # 정규화된 값. "내가 해몽한 꿈" 표시는 FE가 이 값으로 전체보기 목록에서 매칭한다.
        )

    async def get_ranking(self) -> DemoRankingResponse:
        rows = await self.demo_repo.get_today_ranking(_today_kst_for_db())
        items = [DemoRankingItem(rank=i + 1, category=row.category) for i, row in enumerate(rows)]
        return DemoRankingResponse(date=_today_kst().isoformat(), items=items)
```

카운터 증가를 LLM 호출 **이후**로 미룬 이유: LLM이 503으로 실패하면 그 시도는 사용자의 하루 2회 한도에서 차감하지 않는다(스펙에 명시되진 않았지만, 실패한 시도로 쿼터를 태우면 사용자 경험이 나빠지고 스펙 5장의 "해몽이 죽어도 페이지는 뜬다" 원칙과 어긋난다 — 실행 중 이 판단이 스펙과 다르면 알려달라).

- [ ] **Step 2: 검증**

```bash
cd BE
python -m py_compile app/services/demoService.py
```

- [ ] **Step 3: Commit**

```bash
git add BE/app/services/demoService.py
git commit -m "feat: 데모 해몽 서비스 추가 (3중 남용 방지 + 카테고리 정규화)"
```

---

## Task 6: demoApi.py + main.py — 라우터·CORS 등록

**Files:**
- Create: `BE/app/api/demoApi.py`
- Modify: `BE/app/main.py`

**Interfaces:**
- Consumes: `DemoService`(Task 5), `DemoInterpretRequest`/`DemoInterpretResponse`/`DemoRankingResponse`(Task 3).

- [ ] **Step 1: demoApi.py 작성**

```python
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse
from app.schemas.demoSchema import DemoInterpretRequest, DemoInterpretResponse, DemoRankingResponse
from app.services.demoService import DemoService, DemoRateLimitError, DemoUnavailableError

router = APIRouter()
demo_service = DemoService()


def _get_client_ip(request: Request) -> str:
    # Render는 프록시 뒤에 있어 request.client.host는 방문자가 아니라 내부 프록시 IP다.
    # 아래 print는 배포 후 실제 헤더 순서를 확인하기 위한 1회성 로그다(스펙 3.4 "구현 시 반드시 검증할 것").
    # 확인 후에도 남겨둘지, 파싱 로직을 교정할지는 로그 결과를 보고 결정한다.
    forwarded_for = request.headers.get("x-forwarded-for")
    print(f"[demo] X-Forwarded-For={forwarded_for!r} client.host={request.client.host if request.client else None}")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


@router.post("/interpret", response_model=DemoInterpretResponse)
async def interpret_dream(body: DemoInterpretRequest, request: Request):
    client_ip = _get_client_ip(request)
    try:
        return await demo_service.interpret(body.dream, client_ip)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except DemoRateLimitError as e:
        # 스펙 3.3의 429 바디는 {"detail", "reason"}이 평평한 구조라 HTTPException(dict detail)로는
        # {"detail": {"detail":..., "reason":...}}처럼 중첩되어 버린다. JSONResponse로 직접 반환한다.
        return JSONResponse(
            status_code=429,
            content={"detail": "지금은 더 해몽할 수 없어요.", "reason": e.reason},
        )
    except DemoUnavailableError:
        raise HTTPException(status_code=503, detail="지금은 해몽을 불러올 수 없어요.")


@router.get("/ranking", response_model=DemoRankingResponse)
async def get_ranking():
    return await demo_service.get_ranking()
```

- [ ] **Step 2: main.py에 CORS + 라우터 등록**

`BE/app/main.py` 상단 import에 추가:

```python
import os
from fastapi.middleware.cors import CORSMiddleware
from app.api import userApi, chatApi, chatSessionApi, storeApi, reportApi, demoApi
```

(기존 `from app.api import userApi, chatApi, chatSessionApi,storeApi,reportApi` 줄을 위와 같이 `demoApi` 추가해 교체)

`app = FastAPI(lifespan=lifespan)` 바로 다음 줄에 CORS 미들웨어 추가:

```python
app = FastAPI(lifespan=lifespan)

_web_origins = [o.strip() for o in os.getenv("WEB_ORIGIN", "").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_web_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)
```

파일 끝 라우터 등록부에 추가:

```python
app.include_router(demoApi.router, prefix="/demo", tags=["Demo"])
```

- [ ] **Step 3: 검증 — 정상 해몽 + IP 제한**

```bash
cd BE
python -m py_compile app/api/demoApi.py app/main.py
uvicorn app.main:app --reload
```

다른 터미널에서:

```bash
curl -s -X POST http://localhost:8000/demo/interpret -H "Content-Type: application/json" -d "{\"dream\": \"뱀한테 쫓기는 꿈을 꿨어요\"}"
# 기대: 200, theme/vibe/suggested_feelings/ai_reply/remaining:1/dream_category(13종 중 하나)

curl -s -X POST http://localhost:8000/demo/interpret -H "Content-Type: application/json" -d "{\"dream\": \"다시 꿈\"}"
# 기대: 200, remaining:0

curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8000/demo/interpret -H "Content-Type: application/json" -d "{\"dream\": \"세번째\"}"
# 기대: 429, reason: ip
```

- [ ] **Step 4: 검증 — 길이 제한**

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8000/demo/interpret -H "Content-Type: application/json" -d "{\"dream\": \"\"}"
# 기대: 400
python -c "print('{\"dream\": \"' + 'a'*501 + '\"}')" > /tmp/long_dream.json 2>/dev/null || echo "Windows는 PowerShell로 생성"
```

(Windows에서는 PowerShell로 501자 문자열을 만들어 같은 방식으로 400을 확인한다.)

- [ ] **Step 5: 검증 — 전역 상한**

```bash
DEMO_DAILY_GLOBAL_LIMIT=1 uvicorn app.main:app --reload
```

2회 연속 호출 → 두 번째가 429, `reason: "global"` 확인.

- [ ] **Step 6: 검증 — 랭킹 + CORS + 앱 회귀**

```bash
curl -s http://localhost:8000/demo/ranking
# 기대: 200, date + items(상한 없음 — 오늘 1건 이상 집계된 카테고리만, rank/category만, 횟수 없음)

curl -s -X OPTIONS http://localhost:8000/demo/interpret \
  -H "Origin: http://localhost:5500" \
  -H "Access-Control-Request-Method: POST" -i
# WEB_ORIGIN에 http://localhost:5500을 넣고 재기동한 뒤 Access-Control-Allow-Origin 헤더 확인
# WEB_ORIGIN에 없는 Origin으로는 헤더가 없어야 함
```

기존 앱 플로우(`POST /chatting/message`)도 로그인→세션 생성 후 재호출해 여전히 200이 나오는지 확인한다(Task 2에서 추가한 `dream_category` 필드가 앱 응답에 실려도 FE가 무시하므로 영향 없어야 함).

- [ ] **Step 7: 검증 — 카테고리 정규화, 랭킹 날짜 분리, LLM 실패 처리 (스펙 6장 표 항목)**

이 세 항목은 실제 LLM 응답에 의존하거나 과거 날짜 데이터가 필요해 curl만으로 확인하기 어렵다. 아래 일회성 스크립트로 확인한다.

```python
# BE/scratch_check_demo_service.py (검증 후 삭제)
import asyncio
from datetime import timedelta
from dotenv import load_dotenv
load_dotenv()
from app.core.db import db
from app.repositories.demoRepository import DemoRepository
from app.services import demoService
from app.services.demoService import _today_kst_for_db
from app.schemas.chatSchema import AIAnalysisResponse

async def fake_analyze(**kwargs):
    return AIAnalysisResponse(
        theme="t", vibe="v", suggested_feelings=["a", "b", "c"],
        ai_reply="reply", dream_category="외계인",  # 목록 밖 값
    )

async def main():
    await db.connect()
    demoService.analyze_dream_chat = fake_analyze  # 카테고리 정규화 확인용 스텁
    service = demoService.DemoService()
    result = await service.interpret("스텁 테스트용 꿈", "127.0.0.1")
    print("interpret 결과:", result)

    repo = DemoRepository()
    today = _today_kst_for_db()  # naive datetime(자정) — 서비스가 쓰는 것과 같은 값
    rows = await repo.get_today_ranking(today)
    categories = [r.category for r in rows]
    print("카테고리 정규화:", "기타" in categories and "외계인" not in categories)

    # 랭킹 날짜 분리: 어제 날짜로 직접 upsert 후 오늘 조회에 안 나오는지 확인
    yesterday = today - timedelta(days=1)
    await repo.increment_category_count(yesterday, "어제전용카테고리")
    rows_today = await repo.get_today_ranking(today)
    print("날짜 분리:", "어제전용카테고리" not in [r.category for r in rows_today])

    # 동률 정렬: count가 같은 두 카테고리를 만들고 category 오름차순인지 확인
    await repo.increment_category_count(today, "죽음")
    await repo.increment_category_count(today, "시험")
    rows_tie = await repo.get_today_ranking(today)
    tie_names = [r.category for r in rows_tie if r.category in ("죽음", "시험")]
    print("동률 가나다순:", tie_names)  # ["시험", "죽음"] 순서여야 함(둘의 count가 같다는 전제)

    await db.disconnect()

asyncio.run(main())
```

실행: `cd BE && python scratch_check_demo_service.py` → 두 확인 모두 `True` 출력 후 파일 삭제. DB에 남은 테스트용 행(`외계인`이 아닌 `기타`, `어제전용카테고리`)은 `demo_dream_counts` 테이블에서 수동 삭제하거나 그대로 두어도 5장의 "용량 무의미" 판단상 무해하다.

LLM 실패 → 503 확인: `.env`의 `GEMINI_API_KEY`를 비운 상태로 서버를 재기동한 뒤

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8000/demo/interpret -H "Content-Type: application/json" -d "{\"dream\": \"키 없는 상태 테스트\"}"
```

기대: `503`(500이 아님). 확인 후 `GEMINI_API_KEY`를 원래대로 복구한다.

- [ ] **Step 8: Commit**

```bash
git add BE/app/api/demoApi.py BE/app/main.py
git commit -m "feat: 데모 API 라우터 등록 + CORS 설정"
```

---

## Task 7: WEB/ 홈페이지 — 날씨 테마 + 해몽 데모 폼

**변경 이력:** 최초안은 이 태스크에 랭킹까지 한 화면에 넣었다. 디자인 세션 확인 결과 "전체보기"가 상한 없는 아코디언 목록 + 뱃지 + 내 꿈 카드로 커지면서, 별도 페이지(`ranking.html`, Task 8)로 분리했다. 이 태스크는 홈(날씨+해몽 폼)만 담당하고, 랭킹은 미리보기 없이 "전체보기" 링크로만 연결한다.

**Files:**
- Create: `WEB/index.html`
- Create: `WEB/style.css`
- Create: `WEB/app.js`

**Interfaces:**
- Consumes: `POST /demo/interpret`(Task 6), ipapi.co, Open-Meteo(외부 API).
- Produces: `sessionStorage["lastDreamCategory"]`(interpret 성공 시 `dream_category` 저장). Task 8(ranking.html)이 이 값을 읽어 "내가 해몽한 꿈"을 매칭한다. `style.css`는 Task 8과 공유한다.

- [ ] **Step 1: index.html**

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Re-view — 오늘의 꿈 해몽</title>
  <link rel="stylesheet" href="style.css" />
</head>
<body class="theme-clear">
  <main class="page">
    <section id="weather-widget" class="weather-widget" hidden>
      <span id="weather-city"></span>
      <span id="weather-desc"></span>
    </section>

    <h1>오늘 꾼 꿈, 무슨 의미일까요?</h1>

    <form id="interpret-form">
      <textarea id="dream-input" maxlength="500" placeholder="꿈 내용을 적어 주세요 (최대 500자)"></textarea>
      <button type="submit" id="submit-btn">해몽하기</button>
      <p id="input-error" class="error-message" hidden></p>
    </form>

    <section id="result" class="result" hidden>
      <h2 id="result-theme"></h2>
      <p id="result-vibe"></p>
      <ul id="result-feelings"></ul>
      <p id="result-reply"></p>
    </section>

    <a href="ranking.html" class="ranking-link">오늘 사람들이 많이 꾼 꿈 전체보기 →</a>
  </main>

  <div id="exhausted-modal" class="modal" hidden>
    <div class="modal-content">
      <p id="exhausted-message">앱에서 더 해보세요! 앱 설치 시 추가 기회를 무료로 드려요.</p>
      <a href="#" id="app-store-link">앱 설치하러 가기</a>
      <button id="modal-close">닫기</button>
    </div>
  </div>

  <script src="app.js"></script>
</body>
</html>
```

- [ ] **Step 2: style.css**

```css
:root {
  --bg: #eef1f7;
  --fg: #1f2430;
  --accent: #5b6bff;
}

* { box-sizing: border-box; }

body {
  margin: 0;
  font-family: -apple-system, "Pretendard", sans-serif;
  background: var(--bg);
  color: var(--fg);
  transition: background 0.4s ease;
}

.page {
  max-width: 480px;
  margin: 0 auto;
  padding: 24px 16px 80px;
}

.weather-widget {
  display: flex;
  gap: 8px;
  font-size: 14px;
  opacity: 0.8;
  margin-bottom: 16px;
}

textarea {
  width: 100%;
  min-height: 120px;
  padding: 12px;
  border-radius: 12px;
  border: 1px solid #ccc;
  font-size: 16px;
  resize: vertical;
}

button {
  margin-top: 12px;
  width: 100%;
  padding: 14px;
  border: none;
  border-radius: 12px;
  background: var(--accent);
  color: white;
  font-size: 16px;
  cursor: pointer;
}

.error-message {
  color: #d33;
  font-size: 14px;
  margin-top: 8px;
}

.result {
  margin-top: 32px;
  padding: 16px;
  border-radius: 12px;
  background: white;
}

.ranking-link {
  display: block;
  margin-top: 24px;
  text-align: center;
  color: var(--accent);
  font-weight: 600;
  text-decoration: none;
}

.modal {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-content {
  background: white;
  padding: 24px;
  border-radius: 16px;
  max-width: 320px;
  text-align: center;
}

/* 날씨 테마 5종 — 색값은 docs/30-design/01-design-tokens.md 기준으로 추후 조정 */
body.theme-clear { --bg: #eaf4ff; }
body.theme-cloudy { --bg: #e3e6ea; }
body.theme-fog { --bg: #ececec; }
body.theme-rain { --bg: #cfd8e3; }
body.theme-snow { --bg: #f5f8ff; }
```

- [ ] **Step 3: app.js**

```javascript
const API_BASE_URL = "http://localhost:8000"; // 배포 시 Render URL로 교체

const WMO_THEME_MAP = {
  clear: [0, 1],
  cloudy: [2, 3],
  fog: [45, 48],
  rain: [51, 52, 53, 54, 55, 56, 57, 61, 62, 63, 64, 65, 66, 67, 80, 81, 82, 95, 96, 97, 98, 99],
  snow: [71, 72, 73, 74, 75, 76, 77, 85, 86],
};

function themeForWmoCode(code) {
  for (const [theme, codes] of Object.entries(WMO_THEME_MAP)) {
    if (codes.includes(code)) return theme;
  }
  return "clear";
}

// ipapi.co가 차단되거나 레이트리밋에 걸려도 날씨는 보여준다. 스펙상 폴백 좌표는 서울이다.
const SEOUL_COORDS = { latitude: 37.5665, longitude: 126.978 };

async function fetchLocation() {
  try {
    const res = await fetch("https://ipapi.co/json/");
    if (!res.ok) throw new Error("ipapi 응답 실패");
    const geo = await res.json();
    // 레이트리밋에 걸리면 200이면서 {"error": true}를 준다. ok만으로는 판정할 수 없어 좌표 유무로 본다.
    if (typeof geo.latitude !== "number" || typeof geo.longitude !== "number") {
      throw new Error("ipapi 좌표 없음");
    }
    return { latitude: geo.latitude, longitude: geo.longitude, city: geo.city || "" };
  } catch (e) {
    // 폴백 시 도시명은 비운다 — 추측한 위치를 사실처럼 표시하지 않기 위해서다.
    console.warn("위치 조회 실패, 서울 좌표로 폴백:", e);
    return { ...SEOUL_COORDS, city: "" };
  }
}

async function loadWeather() {
  const { latitude, longitude, city } = await fetchLocation();

  try {
    const weatherRes = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current_weather=true`
    );
    if (!weatherRes.ok) throw new Error("open-meteo 실패");
    const weather = await weatherRes.json();
    const code = weather.current_weather.weathercode;

    document.body.className = `theme-${themeForWmoCode(code)}`;
    document.getElementById("weather-city").textContent = city;
    document.getElementById("weather-desc").textContent = `현재 기온 ${weather.current_weather.temperature}°C`;
    document.getElementById("weather-widget").hidden = false;
  } catch (e) {
    // 날씨가 죽어도 페이지는 뜬다 — 기본 테마를 유지하고 위젯만 숨긴다.
    console.warn("날씨 로딩 실패:", e);
  }
}

function showExhaustedModal(reason) {
  const message = document.getElementById("exhausted-message");
  message.textContent =
    reason === "global"
      ? "지금 많은 분들이 이용 중이에요. 앱에서는 대기 없이 이용할 수 있어요!"
      : "오늘 무료 체험을 다 쓰셨어요. 앱 설치 시 추가 기회를 무료로 드려요!";
  document.getElementById("exhausted-modal").hidden = false;
}

async function submitDream(event) {
  event.preventDefault();
  const input = document.getElementById("dream-input");
  const errorEl = document.getElementById("input-error");
  const submitBtn = document.getElementById("submit-btn");
  errorEl.hidden = true;

  const dream = input.value.trim();
  if (dream.length < 1 || dream.length > 500) {
    errorEl.textContent = "꿈 내용은 1~500자로 입력해 주세요.";
    errorEl.hidden = false;
    return;
  }

  submitBtn.disabled = true;
  submitBtn.textContent = "해몽하는 중…";
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);
    const res = await fetch(`${API_BASE_URL}/demo/interpret`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ dream }),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (res.status === 429) {
      const body = await res.json();
      showExhaustedModal(body.reason);
      return;
    }
    if (res.status === 400) {
      const body = await res.json();
      errorEl.textContent = body.detail;
      errorEl.hidden = false;
      return;
    }
    if (!res.ok) {
      errorEl.textContent = "잠시 후 다시 시도해 주세요.";
      errorEl.hidden = false;
      return;
    }

    const result = await res.json();
    document.getElementById("result-theme").textContent = result.theme;
    document.getElementById("result-vibe").textContent = result.vibe;
    const feelingsEl = document.getElementById("result-feelings");
    feelingsEl.innerHTML = "";
    for (const feeling of result.suggested_feelings) {
      const li = document.createElement("li");
      li.textContent = feeling;
      feelingsEl.appendChild(li);
    }
    document.getElementById("result-reply").textContent = result.ai_reply;
    document.getElementById("result").hidden = false;

    // "내가 해몽한 꿈" — 서버는 방문자를 식별하지 않으므로 클라이언트가 세션 동안만 들고 있는다.
    sessionStorage.setItem("lastDreamCategory", result.dream_category);

    if (result.remaining <= 0) {
      showExhaustedModal("ip");
    }
  } catch (e) {
    errorEl.textContent = "잠시 후 다시 시도해 주세요.";
    errorEl.hidden = false;
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = "해몽하기";
  }
}

document.getElementById("interpret-form").addEventListener("submit", submitDream);
document.getElementById("modal-close").addEventListener("click", () => {
  document.getElementById("exhausted-modal").hidden = true;
});

loadWeather();
```

- [ ] **Step 4: 검증**

빌드 도구가 없으므로 파일을 직접 브라우저로 연다(또는 `python -m http.server 5500`으로 `WEB/`을 서빙). `app.js`의 `API_BASE_URL`을 로컬 BE(`http://localhost:8000`)로 맞추고, Task 6에서 그 origin(`http://localhost:5500`)을 `WEB_ORIGIN`에 넣은 뒤 BE를 재기동한 상태에서:

| 확인 항목 | 방법 |
|---|---|
| 테마 5종 | `WMO_THEME_MAP`을 콘솔에서 임시로 `themeForWmoCode(61)` 등으로 호출해 5종 모두 클래스 반환 확인 |
| 위치 실패 폴백 | 브라우저 개발자도구에서 ipapi.co 요청을 차단(net::ERR_BLOCKED)해도 페이지가 정상 렌더되는지 |
| 소진 팝업 | 같은 브라우저로 3번째 시도 시 팝업 노출 |
| 모바일 폭 | 개발자도구 반응형 모드 375px 폭에서 레이아웃 확인 |
| sessionStorage | 해몽 성공 후 개발자도구 Application 탭에서 `lastDreamCategory` 키에 카테고리 값이 저장됐는지 |

- [ ] **Step 5: Commit**

```bash
git add WEB/index.html WEB/style.css WEB/app.js
git commit -m "feat: 홍보 웹페이지 홈 추가 (날씨 테마 + 해몽 데모)"
```

---

## Task 8: WEB/ranking.html — "전체보기" (뱃지 + 아코디언 + 내 꿈 카드)

**참고 자료:** `드림다이어리-디자인` 세션이 만든 시안(Artifact `aef54b51-2138-4ce9-a2ee-d86bf939a41a`, "꿈 랭킹 전체보기 A안 수정본"). 이 태스크는 그 시안의 **기능**(순위·카테고리·길흉 뱃지·한 줄 요약·펼침 시 전체 해몽 텍스트·내 꿈 강조)을 구현하되, 시각 스타일은 Task 7의 기존 `style.css` 톤(단순한 카드/버튼 스타일)을 그대로 확장한다 — 시안의 세리프 폰트·색 토큰 전체를 그대로 가져오는 것은 이 페이지 범위를 넘는 별도 디자인 작업이라 포함하지 않는다. 시안과 톤이 다르게 느껴지면 실행 중에 알려달라.

**보류된 것:** 카테고리 검색창. 카테고리 총 개수가 확정(13종 유지 vs 대규모 확장)될 때까지 넣지 않는다(Global Constraints 참고).

**Files:**
- Create: `WEB/ranking.html`
- Create: `WEB/categoryDictionary.js` — 카테고리별 길흉·해몽 텍스트 FE 정적 사전(BE 변경 불필요, 디자인 세션 확인 사항)
- Modify: `WEB/style.css` — 랭킹 페이지 전용 클래스 추가
- Create: `WEB/ranking.js`

**Interfaces:**
- Consumes: `GET /demo/ranking`(Task 6, 응답 `{date, items: [{rank, category}]}`), `sessionStorage["lastDreamCategory"]`(Task 7이 저장).

- [ ] **Step 1: categoryDictionary.js — FE 정적 사전**

시안에 나온 12종 + 스펙 3.6에는 있지만 시안엔 없는 "기타"(집계 목적의 잡음 버킷이라 고정된 전통 해몽이 없음, 중립 처리) 총 13종:

```javascript
// luck: "g"=길몽, "h"=흉몽, "b"=양면(조건에 따라 갈림)
const CATEGORY_DICTIONARY = {
  "뱀": { luck: "g", summary: "재물과 임신을 알리는 대표 길몽", text: "구렁이나 큰 뱀이 몸을 감거나 품에 안기는 꿈은 예로부터 재물과 태몽의 대표적인 길몽으로 봤다. 뱀에게 물리는 꿈도 흉하게 보지 않고 물린 자리로 복이 들어온다고 풀이한다. 다만 뱀을 죽이거나 쫓아내는 꿈은 들어오던 복을 스스로 밀어내는 것으로 본다." },
  "이빨": { luck: "b", summary: "빠지면 근심, 새로 나면 경사", text: "이가 빠지는 꿈은 가까운 사람의 우환이나 손실을 알리는 대표적인 흉몽이다. 윗니는 손윗사람, 아랫니는 손아랫사람 쪽 일로 나눠 보기도 한다. 반대로 이가 새로 돋는 꿈은 집안에 경사가 생기거나 건강이 회복되는 길몽으로 풀이한다." },
  "똥": { luck: "g", summary: "예로부터 재물이 들어오는 꿈", text: "똥을 밟거나 몸에 묻는 꿈은 재물이 들어오는 대표적인 길몽이다. 양이 많고 더러울수록 크게 본다. 다만 똥을 씻어내거나 치우는 꿈은 들어온 재물이 다시 빠져나가는 것으로 풀이한다." },
  "쫓김": { luck: "h", summary: "미뤄둔 일이 주는 압박", text: "쫓기는 꿈은 현실에서 감당하지 못하고 미뤄둔 일이 압박으로 돌아온 것으로 본다. 붙잡히면 그 일이 결국 닥친다는 뜻이고, 끝내 도망쳐 벗어나면 고비를 넘긴다는 풀이다. 쫓아오던 대상이 무엇이었는지가 풀이의 핵심이 된다." },
  "물": { luck: "b", summary: "맑으면 순조, 흐리면 지체", text: "맑은 물은 재물과 건강이 순조롭게 흐르는 것으로, 흐리거나 탁한 물은 일이 막히고 구설이 따르는 것으로 나눠 본다. 물이 불어나 넘치는 꿈은 큰 재물로 보고, 마르거나 빠지는 꿈은 손실로 풀이한다." },
  "불": { luck: "g", summary: "크게 번질수록 번창한다", text: "불이 활활 타오르거나 집 전체로 번지는 꿈은 사업과 재물이 크게 일어나는 길몽이다. 연기만 자욱하고 불길이 보이지 않으면 헛수고나 구설로 본다. 불을 끄는 꿈은 일어나던 기운을 스스로 눌러앉히는 것으로 풀이한다." },
  "돼지": { luck: "g", summary: "돈과 복이 함께 들어온다", text: "돼지가 집으로 들어오거나 품에 안기는 꿈은 재물운의 대표적 길몽이다. 돼지를 붙잡거나 안아 올리면 그 복을 실제로 손에 넣는 것으로 본다. 반대로 돼지가 달아나는 꿈은 눈앞의 기회를 놓치는 것으로 풀이한다." },
  "죽음": { luck: "g", summary: "끝이 아니라 새로 시작한다", text: "죽는 꿈은 실제 죽음이 아니라 지금의 처지가 끝나고 새 국면이 열리는 것으로 본다. 자기 자신이 죽는 꿈일수록 크게 바뀌는 길몽으로 풀이한다. 다만 죽어가는 것을 지켜보기만 하는 꿈은 변화를 남의 일로 미루는 상태로 본다." },
  "조상님": { luck: "b", summary: "곧 닥칠 일에 대한 예고", text: "조상이 나타나는 꿈은 길흉을 가리지 않고 앞으로 있을 일을 미리 알리는 것으로 본다. 표정이 밝고 무언가를 건네주면 도움과 재물이 오는 것이고, 어둡거나 등을 돌리면 조심하라는 경고로 풀이한다." },
  "높은곳": { luck: "b", summary: "오르면 성취, 떨어지면 불안", text: "산이나 계단을 끝까지 올라 정상에 서는 꿈은 승진과 성취의 길몽이다. 반대로 오르다 미끄러지거나 떨어지는 꿈은 진행하던 일이 좌절되거나 자리가 흔들리는 것으로 본다. 떨어지다 깨는 꿈은 대개 현실의 불안이 그대로 비친 것이다." },
  "시험": { luck: "h", summary: "준비 못 한 것에 대한 불안", text: "시험을 보는 꿈은 대개 평가받는 자리를 앞둔 불안이 그대로 나타난 것이다. 문제를 못 풀거나 시간이 모자라는 꿈일수록 준비가 덜 됐다고 스스로 느끼는 상태로 본다. 오히려 시험을 잘 치르는 꿈은 방심을 경계하라는 뜻으로 풀이하기도 한다." },
  "피": { luck: "g", summary: "재물 혹은 건강의 신호", text: "피를 보는 꿈은 흉하게 여기기 쉽지만 전통 해몽에서는 재물이 들어오는 길몽으로 본다. 옷이나 몸에 묻을수록, 양이 많을수록 크게 풀이한다. 다만 피를 닦아내거나 멈추게 하는 꿈은 들어오던 재물이 새는 것으로 본다." },
  "기타": { luck: "b", summary: "정해진 상징에 딱 들어맞지 않는 꿈", text: "위 12종 어디에도 뚜렷이 속하지 않는 꿈이다. 전통 해몽에 고정된 풀이가 없으므로 특정 길흉으로 단정하지 않는다." },
};

const LUCK_LABEL = { g: "길몽", h: "흉몽", b: "양면" };
```

- [ ] **Step 2: ranking.html**

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Re-view — 오늘 사람들이 많이 꾼 꿈</title>
  <link rel="stylesheet" href="style.css" />
</head>
<body>
  <main class="page ranking-page">
    <a href="index.html" class="back-link">‹ 뒤로</a>

    <div class="ranking-header">
      <h1>오늘 사람들이 많이 꾼 꿈</h1>
      <p id="ranking-date" class="date"></p>
    </div>

    <div id="mine-card" class="mine-card" hidden>
      <span class="mine-label">내가<br />해몽한 꿈</span>
      <span id="mine-name" class="mine-name"></span>
      <span id="mine-rank" class="mine-rank"></span>
      <button id="mine-goto" class="mine-goto">순위 보기</button>
    </div>

    <ol id="ranking-list" class="ranking-list"></ol>
    <p id="ranking-empty" class="ranking-empty" hidden>아직 오늘 해몽된 꿈이 없어요.</p>
    <p id="ranking-error" class="error-message" hidden>랭킹을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.</p>
  </main>

  <script src="categoryDictionary.js"></script>
  <script src="ranking.js"></script>
</body>
</html>
```

- [ ] **Step 3: ranking.js**

```javascript
const API_BASE_URL = "http://localhost:8000"; // 배포 시 Render URL로 교체

function luckBadgeHtml(category) {
  const entry = CATEGORY_DICTIONARY[category];
  const luck = entry ? entry.luck : "b";
  return `<span class="badge badge-${luck}">${LUCK_LABEL[luck]}</span>`;
}

function buildRow(item, myCategory) {
  const entry = CATEGORY_DICTIONARY[item.category] || {
    summary: "아직 해몽 사전에 없는 카테고리예요.",
    text: "이 카테고리는 아직 전통 해몽 사전에 등록되지 않았어요.",
  };
  const isMine = item.category === myCategory;

  const li = document.createElement("li");
  li.className = "ranking-item" + (isMine ? " is-mine" : "");
  li.dataset.category = item.category;
  li.innerHTML = `
    <button class="ranking-row" aria-expanded="false">
      <span class="rank">${item.rank}</span>
      <span class="name">${item.category}</span>
      ${luckBadgeHtml(item.category)}
      <span class="summary">${entry.summary}</span>
      ${isMine ? '<span class="mine-tag">내 꿈</span>' : ""}
      <span class="chevron">⌄</span>
    </button>
    <div class="ranking-panel" hidden>
      <p class="ranking-panel-text">${entry.text}</p>
      ${isMine ? '<p class="ranking-panel-foot">오늘 이 꿈을 해몽했습니다.</p>' : ""}
    </div>
  `;

  li.querySelector(".ranking-row").addEventListener("click", () => {
    const expanded = li.classList.toggle("open");
    li.querySelector(".ranking-row").setAttribute("aria-expanded", String(expanded));
    li.querySelector(".ranking-panel").hidden = !expanded;
  });

  return li;
}

async function loadRanking() {
  const myCategory = sessionStorage.getItem("lastDreamCategory");

  try {
    const res = await fetch(`${API_BASE_URL}/demo/ranking`);
    if (!res.ok) throw new Error("랭킹 실패");
    const data = await res.json();

    document.getElementById("ranking-date").textContent = `${data.date} · 오늘 해몽된 꿈만 모았습니다`;

    if (data.items.length === 0) {
      document.getElementById("ranking-empty").hidden = false;
      return;
    }

    const list = document.getElementById("ranking-list");
    list.innerHTML = "";
    for (const item of data.items) {
      list.appendChild(buildRow(item, myCategory));
    }

    const mine = data.items.find((item) => item.category === myCategory);
    if (mine) {
      document.getElementById("mine-name").textContent = mine.category;
      document.getElementById("mine-rank").textContent = `오늘 ${mine.rank}위`;
      document.getElementById("mine-card").hidden = false;
      document.getElementById("mine-goto").addEventListener("click", () => {
        const target = list.querySelector(`[data-category="${mine.category}"]`);
        target?.scrollIntoView({ behavior: "smooth", block: "center" });
      });
    }
  } catch (e) {
    console.warn("랭킹 로딩 실패:", e);
    document.getElementById("ranking-error").hidden = false;
  }
}

loadRanking();
```

- [ ] **Step 4: style.css에 랭킹 페이지 클래스 추가**

기존 `style.css` 끝에 추가:

```css
.ranking-page { max-width: 640px; }

.back-link {
  display: inline-block;
  margin-bottom: 16px;
  color: var(--fg);
  text-decoration: none;
  opacity: 0.7;
}

.ranking-header .date {
  color: #666;
  font-size: 13px;
  margin: 4px 0 20px;
}

.mine-card {
  display: flex;
  align-items: center;
  gap: 12px;
  background: #f3f0e8;
  border: 1px solid #d9d2c4;
  border-radius: 12px;
  padding: 12px 16px;
  margin-bottom: 20px;
  font-size: 13px;
}

.mine-name { font-weight: 700; font-size: 16px; }
.mine-rank { margin-left: auto; font-size: 13px; }
.mine-goto {
  width: auto;
  margin-top: 0;
  padding: 6px 12px;
  font-size: 12px;
  border-radius: 8px;
}

.ranking-list { list-style: none; margin: 0; padding: 0; }

.ranking-item { border-bottom: 1px solid #e3dfd7; }
.ranking-item.is-mine, .ranking-item.open {
  background: #f3f0e8;
  border-radius: 10px;
}

.ranking-row {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 12px;
  background: none;
  border: none;
  text-align: left;
  cursor: pointer;
  font-size: 15px;
  color: var(--fg);
}

.ranking-row .rank { font-weight: 600; color: #999; width: 20px; }
.ranking-row .name { font-weight: 600; }
.ranking-row .summary {
  flex: 1;
  color: #777;
  font-size: 13px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ranking-row .mine-tag {
  font-size: 10px;
  border: 1px solid #d9d2c4;
  border-radius: 5px;
  padding: 2px 6px;
  color: #777;
}
.ranking-item.open .chevron { transform: rotate(180deg); }

.ranking-panel { padding: 0 12px 16px 42px; }
.ranking-panel-text { font-size: 14px; line-height: 1.7; color: #333; margin: 0; }
.ranking-panel-foot { font-size: 12px; color: #888; margin: 8px 0 0; }

.badge {
  font-size: 11px;
  font-weight: 600;
  border-radius: 6px;
  padding: 2px 8px;
  white-space: nowrap;
}
.badge-g { color: #2f6b4f; background: #e9f0ea; }
.badge-h { color: #9e4e38; background: #f6ebe7; }
.badge-b { color: #6e655a; background: #efebe4; }

.ranking-empty { color: #888; text-align: center; margin-top: 40px; }

@media (max-width: 480px) {
  .ranking-row .summary { display: none; }
}
```

- [ ] **Step 5: 검증**

```bash
python -m http.server 5500  # WEB/ 디렉터리에서
```

Task 6 BE를 로컬로 띄운 상태에서(`WEB_ORIGIN`에 `http://localhost:5500` 포함):

| 확인 항목 | 방법 |
|---|---|
| 상한 없는 목록 | Task 6에서 서로 다른 카테고리로 6회 이상 해몽 호출 후 `ranking.html`에서 6개 이상 행이 뜨는지(5개로 안 잘리는지) |
| 뱃지 3종 | 길몽·흉몽·양면 카테고리 각각 해몽해 배경색·라벨이 다른지 |
| 아코디언 | 행 클릭 시 전통 해몽 전체 텍스트가 펼쳐지고, 다시 누르면 접히는지 |
| 내가 해몽한 꿈 | 해몽 후 `index.html` → "전체보기" 링크로 이동, 내 카테고리 행에 "내 꿈" 태그·강조 배경이 붙고 상단 카드에 순위가 뜨는지, "순위 보기" 클릭 시 그 행으로 스크롤되는지 |
| 세션 분리 | 시크릿 창으로 새로 열면(sessionStorage 없음) 내 꿈 카드가 안 뜨는지 |
| 빈 상태 | DB에 오늘 데이터가 없는 상태로 열면 "아직 오늘 해몽된 꿈이 없어요" 문구가 뜨는지 |
| 모바일 폭 | 375px에서 한 줄 요약(summary)이 숨겨지고 순위·이름·뱃지만 보이는지 |
| 랭킹 실패 처리 | BE를 잠깐 내린 상태로 열어 "랭킹을 불러오지 못했어요" 문구가 뜨는지(스펙 5장 실패 처리 원칙) |

- [ ] **Step 6: Commit**

```bash
git add WEB/ranking.html WEB/ranking.js WEB/categoryDictionary.js WEB/style.css
git commit -m "feat: 전체보기 페이지 추가 (길흉 뱃지 + 아코디언 + 내가 해몽한 꿈)"
```

---

## 실행 후 남는 일 (계획 범위 밖 — 스펙 8장 "미정 사항")

- 정적 호스팅 업체 선정(Vercel 권장) 및 실제 배포
- Render 대시보드에 `WEB_ORIGIN`, `DEMO_DAILY_GLOBAL_LIMIT` 환경변수 입력(`render.yaml`은 `sync: false`)
- 배포 후 `X-Forwarded-For` 헤더 실측 확인(스펙 3.4) — 서로 다른 네트워크 2곳에서 각각 2회씩 해몽되는지 확인
- 페이지 카피, 비주얼, 앱 스토어 링크 확정
- **카테고리 총 개수 확정** — 13종 유지 vs 대규모 확장(예시 100종). 확정되면: (a) Task 2의 `CATEGORY_LIST`·프롬프트, (b) Task 5의 `CATEGORY_LIST`, (c) Task 8의 `categoryDictionary.js`, (d) Notion 웹 API 명세 갱신. 목록이 커지면 Task 8에 보류해둔 카테고리 검색창도 그때 추가
- Task 8의 시각 스타일이 디자인 세션 시안과 다르게 갈 경우, 실제 톤 맞추기(폰트·색 토큰)는 별도 디자인 작업으로 처리
