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

# DB 마이그레이션 적용 (반드시 루트에서)
cd C:\dev\dream_diary
prisma migrate deploy --schema=BE/prisma/schema.prisma

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
- **이미지 URL**: `.env`의 `SERVER_BASE_URL`을 사용하며, 없으면 코드 폴백값(`chatService.py`의 고정 IP)을 쓴다. 이 폴백값은 **폐기된 EC2 IP라 더 이상 유효하지 않으므로** 반드시 `.env`에 실제 배포 주소를 넣어야 한다.
- **배포 구성**: AWS EC2는 종료됐다. 현재는 DB = Neon(PostgreSQL 18 + pgvector), 앱 = Render 무료 웹 서비스(`render.yaml` Blueprint). nginx는 Render가 TLS를 종료하므로 쓰지 않는다. 자세한 절차는 `README.md`의 배포 항목 참고.
- **비밀번호**: bcrypt 해시(`core/security.py`의 `hash_password`/`verify_password`). 평문 저장 금지.
- **Prisma 스키마 변경**: `prisma/schema.prisma` 수정 후 `prisma generate` 필수. 실 DB 반영은 루트에서 `prisma migrate deploy --schema=BE/prisma/schema.prisma`로 한다. `content_vector`는 3072차원이라 HNSW/IVFFlat 인덱스(2000차원 한계)를 걸 수 없어 의도적으로 보류된 상태다.
- **파일명 컨벤션 불일치**: `user*`만 복수형(`userServices.py`, `userRepositories.py`), 나머지 도메인은 단수형(`chatService.py` 등). 기존 파일을 수정할 때 그 파일의 관례를 따른다.
