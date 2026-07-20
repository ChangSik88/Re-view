# 풀스택 루트 구조 개편 설계

## 목표
BE/FE를 풀스택으로 함께 관리하기 위해, BE의 설정·패키지·가상환경 파일을 루트로 끌어올려 관리 지점을 일원화한다. FE(Flutter)는 플랫폼 빌드 스크립트가 `pubspec.yaml` 기준 상대경로에 묶여 있어 표준 구조 그대로 둔다.

## 범위
- BE의 루트 이동 대상: `requirements.txt`, `.env`, `venv/`, README, `.gitignore`
- BE 앱 코드(`app/`, `prisma/`)는 **한 줄도 수정하지 않는다.**
- FE는 전혀 건드리지 않는다.

## 변경 후 구조
```
dream_diary/
├── README.md          (신규: 프로젝트 개요 + BE/FE 실행 명령어)
├── requirements.txt    (BE/ → 루트)
├── .env                (BE/ → 루트, git 미추적)
├── .gitignore          (신규 통합)
├── venv/               (BE/venv → 루트)
├── BE/
│   ├── app/            (그대로)
│   └── prisma/         (그대로)
└── FE/                 (그대로)
```

## 실행 방식 (README 안내)
스크립트 파일은 두지 않고 README에 명령어로 안내한다.

- 최초 설치: `python -m venv venv` → activate → `pip install -r requirements.txt` → (FE) `cd FE && flutter pub get`
- BE 실행: (루트) `venv\Scripts\activate` → `cd BE` → `uvicorn app.main:app --reload`
- FE 실행: `cd FE` → `flutter run`

## 코드 수정이 불필요한 근거
- **`app/static`, prisma 상대경로**: uvicorn을 `BE/`를 cwd로 실행하므로 기존과 동일하게 작동한다.
- **`.env` 로드**: python-dotenv의 `load_dotenv()`는 호출한 소스 파일 위치에서 상위 폴더로 `.env`를 탐색한다. BE에서 실행하면 상위(루트)의 `.env`를 자동으로 찾으므로 코드 수정이 없다.

## 삭제 대상
- `BE/README.md` (루트 README로 통합)
- `BE/requirements.txt`, `BE/.env`, `BE/.gitignore` (루트로 이동)
- `BE/venv/` (루트로 이동)

## 검증 (pass 조건)
1. 루트에서 venv 활성화 + `cd BE` + uvicorn 실행 시 서버가 기동되고 `/` 응답이 온다.
2. `.env`의 `JWT_SECRET_KEY`, `DATABASE_URL`이 정상 로드된다 (기동 시 DB 연결 성공 로그).
3. FE는 변경 없음 — `git status`에 FE 변경이 없다.
