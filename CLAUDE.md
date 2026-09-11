# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

Re-view(dream_diary)는 꿈/하루를 기록하는 풀스택 프로젝트다.

- **BE** (`BE/`): FastAPI + Prisma(PostgreSQL, pgvector). 파이썬 3.13.
- **FE** (`FE/`): Flutter. 안드로이드 연동이 1차 타깃.

설정·패키지·가상환경은 **루트에서 일원화**한다. `requirements.txt`, `.env`, `venv/`는 루트에 있고, BE 앱 코드만 `BE/` 안에 있다. FE는 Flutter 표준 구조라 `FE/` 안에 자체 `pubspec.yaml`을 유지한다.

## 명령어

모든 BE 명령은 **루트에서 venv를 활성화한 뒤 `BE/`로 들어가** 실행한다. `.env`는 루트에 있지만 python-dotenv가 상위 폴더로 탐색하므로 `BE/`에서 실행해도 인식된다.

**단, `prisma migrate` 계열은 예외다.** Prisma CLI(Node)는 `.env`를 cwd 기준 `./.env`·`./prisma/.env`에서만 찾고 상위 폴더로 올라가지 않는다. `BE/`에서 실행하면 `P1012 Environment variable not found: DATABASE_URL`이 난다. **루트에서 `--schema`로 지정해 실행할 것.**

```bash
# 최초 설치 (루트)
python -m venv venv
venv\Scripts\activate            # Windows / macOS·Linux: source venv/bin/activate
pip install -r requirements.txt

# prisma client 생성 (venv 재생성 시 항상 다시 실행)
cd BE
PYTHONUTF8=1 prisma generate     # Windows PowerShell: $env:PYTHONUTF8="1"; prisma generate
                                 # 이 플래그 없으면 schema.prisma의 한글 주석 때문에
                                 # cp949 UnicodeEncodeError로 생성이 중간에 깨진다

# DB 마이그레이션 (반드시 루트에서)
cd C:\dev\dream_diary

# ① 스키마를 고쳤으면 로컬 DB에 대고 마이그레이션 '파일을 만든다'
#    migrate deploy는 파일을 만들지 않는다. 파일 없이 deploy하면 "No pending migrations"만 뜨고
#    테이블은 생기지 않는다. PYTHONUTF8=1이 없으면 뒤이어 자동 실행되는 generate가 cp949로 깨진다.
PYTHONUTF8=1 prisma migrate dev --name <변경_요약> --schema=BE/prisma/schema.prisma

# ② 생성된 BE/prisma/migrations/<타임스탬프>_<이름>/ 을 schema.prisma와 함께 커밋한다.
#    운영 반영은 배포가 한다 — render.yaml의 buildCommand가 migrate deploy를 실행한다.

# ③ 예외적으로 운영 DB에 수동 적용해야 할 때만, URL을 명시해서 실행한다
#    (.env 기본값은 로컬이다. 운영 URL을 기본값 자리에 두지 않는다)
DATABASE_URL="<supabase-url>" prisma migrate deploy --schema=BE/prisma/schema.prisma

# BE 서버 실행
venv\Scripts\activate
cd BE
uvicorn app.main:app --reload                          # 로컬
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload  # 외부 접속(안드로이드)

# FE
cd FE && flutter pub get && flutter run
```

**테스트 프레임워크는 없다.** 변경 검증은 실제 실행으로 한다: `python -m py_compile <파일>`로 문법 확인, 서버 기동 후 `curl`로 엔드포인트 확인, AI/DB 관련은 `load_dotenv()` 후 해당 함수를 직접 호출하는 일회성 스크립트로 확인한다. `prisma generate`가 PATH에서 venv 실행파일을 못 찾으면 `export PATH="<repo>/venv/Scripts:$PATH"`를 앞에 붙인다.

## 아키텍처

BE는 엄격한 4계층이다. 각 도메인(chat, chatSession, report, store, user)이 이 계층을 관통한다:

```
api/ (라우터, HTTP·인증·에러코드)
  → services/ (비즈니스 로직, 데이터 가공, 소유권 검증)
    → repositories/ (Prisma 쿼리만)
      → core/db.py (전역 Prisma 클라이언트 `db`)
```

- **인증**: `api/dependencies.py`의 `get_current_user_id`가 JWT에서 `user_id`를 뽑아 각 라우터에 주입한다. 보호 엔드포인트는 이 의존성을 반드시 건다. 채팅방 접근은 서비스 계층에서 `session.user_id == user_id`로 소유권을 검증한다(`ChatService._get_owned_session`).
- **AI 계층** (`core/ai/`): LLM/이미지 호출을 캡슐화한다. `langchainManager.py`가 채팅 해몽·일기 생성·임베딩을, `reportManager.py`가 경향 분석을, `imageManager.py`가 FLUX 이미지 생성을 담당한다. 서비스는 이 함수들을 호출만 한다.
- **루틴 분기**: 거의 모든 AI 흐름이 `routine_type`("MORNING"/"NIGHT")에 따라 프롬프트를 갈아끼운다. 아침은 전통 해몽, 밤은 하루 회고. 프롬프트 수정 시 두 갈래를 모두 확인할 것.
- **일기 저장**: `ChatService.create_diary`는 일기 텍스트+태그 저장, `content_vector`(pgvector) raw UPDATE, 이미지 생성·저장을 순차 실행한다. 텍스트와 벡터 갱신은 `db.tx()` 트랜잭션으로 원자화되어 있다(부분 저장 방지). 이미지는 실패해도 일기가 유효하도록 트랜잭션 밖이다.
- **벡터 검색용 임베딩**: 일기 생성 시 제목+내용을 임베딩해 `content_vector`에 저장한다(주간 요약/유사도용). 스키마에서 `Unsupported("vector")`라 Prisma ORM으로 못 쓰고 `execute_raw`로 다룬다.

## 주의사항

- **LLM 모델 ID**: 채팅·리포트 모두 `gemini-3.1-flash-lite`. 임베딩은 `gemini-embedding-001`. 모델을 바꾸면 `langchainManager.py`와 `reportManager.py` 두 곳을 함께 바꾼다.
- **API 키**: Gemini는 `.env`의 `GEMINI_API_KEY`를 langchain이 자동 인식한다. 이미지 생성은 `FLUX_API_KEY`.
- **생성 이미지 저장**: `core/storage.py`가 S3 호환 오브젝트 스토리지(Supabase Storage)에 올리고 공개 URL을 DB에 넣는다. Render 무료 티어는 영구 디스크가 없어 로컬 저장이 재배포마다 날아가기 때문이다. `S3_*` 환경 변수 6개가 필요하며, 엔드포인트·리전만 바꾸면 R2/S3에서도 동일하게 동작한다. 삭제 시 키는 URL에서 `S3_PUBLIC_BASE_URL` 접두사를 걷어내 구한다(공개 URL 경로가 곧 키가 아닌 스토리지가 있다). `SERVER_BASE_URL`은 이 이관 이후 코드에서 읽지 않는다.
- **`/static` 마운트**: 상점 이미지(`app/static/storeImages/`)용으로 남아 있다. 이쪽은 git 추적 파일이라 재배포해도 유지된다.
- **배포 구성**: AWS EC2는 종료됐다. 현재는 DB = Supabase(PostgreSQL + pgvector, Storage와 동일 프로젝트), 앱 = Render 무료 웹 서비스(`render.yaml` Blueprint). nginx는 Render가 TLS를 종료하므로 쓰지 않는다. `DATABASE_URL`은 **Session pooler(포트 5432)** 문자열만 쓴다. direct 호스트는 IPv6 전용이라 Render에서 못 붙고, transaction pooler(6543)는 Prisma prepared statement가 깨진다. 처음엔 Neon을 썼으나 외부 cron 핑이 Prisma 커넥션을 24시간 유지시켜 무료 compute 쿼터를 소진시킨 탓에 이관했다. **Supabase는 compute 시간을 재지 않으므로 슬립 방지 cron은 유지한다** — 단 `/`가 아니라 `/item/list`를 10분 간격, 07:00–02:00 KST로 호출한다(`/`는 DB를 안 건드려 Supabase 무활동 타이머를 리셋 못 한다). 전말은 `docs/40-decisions/0001-neon-to-supabase.md`, 절차는 `README.md`의 배포 항목 참고.
- **비밀번호**: bcrypt 해시(`core/security.py`의 `hash_password`/`verify_password`). 평문 저장 금지.
- **Prisma 스키마 변경**: `prisma/schema.prisma` 수정 → `migrate dev`로 마이그레이션 파일 생성(로컬 DB 기준) → 파일 커밋 → 배포가 `migrate deploy`로 운영에 적용. 명령은 위 "명령어" 항목 참고. `content_vector`는 3072차원이라 HNSW/IVFFlat 인덱스(2000차원 한계)를 걸 수 없어 의도적으로 보류된 상태다.
- **개발 DB와 운영 DB**: 개발은 로컬 PostgreSQL(`localhost:5432/dream_diary`, pgvector 설치됨), 운영은 Supabase다. `.env`의 `DATABASE_URL`은 **로컬을 기본값으로 둔다** — 운영을 기본값에 두면 `migrate reset` 같은 파괴적 명령이 실수로 운영에 꽂힌다. Render는 이 `.env`를 읽지 않고 대시보드 환경변수를 쓴다(`render.yaml`에서 `sync: false`).
- **Prisma Python 타입 주의**: `@db.Date` 컬럼에 `datetime.date`를 넘기면 `TypeError: Type <class 'datetime.date'> not serializable`로 터진다. **naive `datetime`(자정)으로 변환해 넘길 것.** tz-aware로 넘기면 UTC 변환 때문에 날짜가 하루 밀릴 수 있다.
- **타임존**: Windows에는 IANA tz DB가 없어 `zoneinfo.ZoneInfo("Asia/Seoul")`이 `ZoneInfoNotFoundError`로 실패한다(Linux인 Render에서는 동작해서, 로컬에서만 깨지는 형태가 된다). 한국은 DST가 없으므로 `timezone(timedelta(hours=9))` 고정 오프셋을 쓴다.
- **파일명 컨벤션 불일치**: `user*`만 복수형(`userServices.py`, `userRepositories.py`), 나머지 도메인은 단수형(`chatService.py` 등). 기존 파일을 수정할 때 그 파일의 관례를 따른다.
