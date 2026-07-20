# 팀 온보딩 가이드

새로 합류한 팀원을 위한 안내서입니다. 이 문서를 처음부터 따라가면 프로젝트를 이해하고 로컬에서 실행할 수 있습니다.

## 1. 이 프로젝트는 무엇인가

**Re-view**는 사용자의 꿈과 하루를 기록하고, AI가 해몽·일기·감정 분석을 도와주는 앱입니다. 하루 두 번의 "루틴"이 핵심입니다.

- **모닝 루틴(MORNING)**: 아침에 방금 꾼 꿈을 이야기하면, AI가 한국 전통 해몽으로 풀이하고 그 꿈을 판타지 단편 소설 형식의 일기로 만들어 줍니다.
- **나이트 루틴(NIGHT)**: 밤에 하루를 이야기하면, AI가 공감·위로하고 하루를 회고 일기로 정리해 줍니다.

여기에 최근 꿈들의 경향을 분석하는 **리포트**, 아이템을 구경하는 **스토어** 기능이 있습니다.

## 2. 기술 스택

| 영역 | 스택 |
|------|------|
| 백엔드 | FastAPI, Prisma(PostgreSQL + pgvector), Python 3.13 |
| AI | LangChain + Google Gemini(`gemini-3.1-flash-lite`), 임베딩(`gemini-embedding-001`), 이미지 생성(FLUX) |
| 프론트엔드 | Flutter (안드로이드 우선) |
| 인증 | JWT (bcrypt 비밀번호 해싱) |

## 3. 폴더 구조

```
dream_diary/
├── README.md          # 설치·실행 명령어 (빠른 참조)
├── CLAUDE.md          # AI 코딩 어시스턴트용 프로젝트 가이드
├── requirements.txt   # BE 파이썬 의존성 (루트에서 관리)
├── .env               # 환경 변수 (git에 없음 — 팀에 별도 요청)
├── venv/              # 파이썬 가상환경 (git에 없음 — 직접 생성)
├── docs/              # 설계 문서·이 온보딩 가이드
├── BE/                # FastAPI 백엔드
│   ├── app/
│   │   ├── api/           # 라우터 (HTTP 엔드포인트, 인증, 에러코드)
│   │   ├── services/      # 비즈니스 로직, 데이터 가공, 소유권 검증
│   │   ├── repositories/  # Prisma 쿼리
│   │   ├── core/
│   │   │   ├── ai/        # LLM·이미지 호출 캡슐화
│   │   │   ├── db.py      # 전역 Prisma 클라이언트
│   │   │   └── security.py# JWT·비밀번호 해싱
│   │   └── schemas/       # Pydantic 요청/응답 모델
│   └── prisma/schema.prisma
└── FE/                # Flutter 프론트엔드
```

## 4. 백엔드 아키텍처 한눈에

요청은 항상 이 순서로 흐릅니다. 새 기능을 만들 때도 이 계층을 지키세요.

```
api (라우터)  →  services (로직)  →  repositories (DB)  →  Prisma / PostgreSQL
```

- **api**: HTTP만 담당. 토큰 검증(`get_current_user_id` 의존성), 예외를 HTTP 상태코드로 변환.
- **services**: 진짜 로직. 여러 repository를 조합하고, "이 채팅방이 이 유저 것인지" 같은 소유권 검증도 여기서 합니다.
- **repositories**: Prisma 쿼리만. 로직 넣지 않기.
- **core/ai**: Gemini/FLUX 호출을 감싼 계층. 서비스는 이 함수들을 호출만 합니다. `routine_type`(MORNING/NIGHT)에 따라 프롬프트가 갈립니다.

## 5. 로컬 환경 세팅

> 자세한 명령어는 [README.md](../README.md)에 있습니다. 여기서는 흐름만 정리합니다.

1. **저장소 클론** 후 루트로 이동
2. **`.env` 파일 받기** — git에 없습니다. 팀에 요청해 루트에 두세요. (필요 키: `DATABASE_URL`, `JWT_SECRET_KEY`, `GEMINI_API_KEY`, `FLUX_API_KEY`, `SERVER_BASE_URL`)
3. **가상환경 생성 + 의존성 설치** (루트에서):
   ```bash
   python -m venv venv
   venv\Scripts\activate         # macOS·Linux: source venv/bin/activate
   pip install -r requirements.txt
   cd BE && prisma generate       # 이걸 안 하면 서버가 "Client hasn't been generated" 에러를 냅니다
   ```
4. **서버 실행**: `cd BE && uvicorn app.main:app --reload` → 브라우저에서 `http://127.0.0.1:8000` 접속 시 성공 메시지가 나오면 OK. API 문서는 `/docs`.
5. **FE 실행**: `cd FE && flutter pub get && flutter run`

## 6. 개발 워크플로

- **브랜치**: `main`에 직접 커밋하지 않습니다. 작업 성격에 따라 `feat/`, `fix/`, `refactor/`, `chore/` 접두사로 브랜치를 만듭니다.
- **PR**: 변경은 PR로 올리고 머지합니다. PR 본문에 **무엇을 왜 바꿨는지 + 어떻게 검증했는지(Test plan)**를 적습니다.
- **검증**: 자동화된 테스트 프레임워크는 아직 없습니다. 바꾼 부분을 실제로 돌려서 확인하세요 — 서버 기동, 엔드포인트 호출, AI 함수 직접 호출 등.

## 7. 처음 겪기 쉬운 문제 · 꼭 알아둘 것

- **`prisma generate`를 안 하면 서버가 안 뜹니다.** venv를 새로 만들 때마다 `cd BE && prisma generate`를 다시 하세요.
- **`.env`는 루트에 둡니다.** BE 안이 아니라 루트입니다. `BE/`에서 uvicorn을 실행해도 python-dotenv가 상위 폴더에서 찾아 인식합니다.
- **기존 테스트 계정으로 로그인이 안 될 수 있습니다.** 비밀번호가 bcrypt 해시로 바뀌었기 때문에, 예전에 평문으로 저장된 계정은 로그인되지 않습니다. 새로 회원가입하세요. (DB를 초기화하면 깔끔합니다.)
- **LLM 모델을 바꿀 땐 두 곳을 함께** 바꿉니다: `core/ai/langchainManager.py`, `core/ai/reportManager.py`.
- **모닝/나이트 프롬프트는 쌍으로 존재합니다.** 프롬프트를 손보면 두 갈래(MORNING/NIGHT)를 모두 확인하세요.
- **파일명 컨벤션이 섞여 있습니다.** `user*`만 복수형(`userServices.py`), 나머지는 단수형(`chatService.py`)입니다. 기존 파일을 고칠 땐 그 파일 관례를 따르세요.

## 8. 더 읽을거리

- [README.md](../README.md) — 설치·실행 명령어
- [CLAUDE.md](../CLAUDE.md) — 아키텍처·주의사항 요약(AI 어시스턴트용이지만 사람이 읽어도 유용)
- `docs/superpowers/specs/` — 주요 변경의 설계 문서
