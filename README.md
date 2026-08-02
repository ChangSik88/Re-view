# Re-view

창업캡스톤디자인2 — 꿈 일기 풀스택 프로젝트

- **BE**: FastAPI + Prisma (PostgreSQL) — `BE/`
- **FE**: Flutter — `FE/`

> 처음 합류했다면 [팀 온보딩 가이드](docs/ONBOARDING.md)부터 읽어보세요.

## 프로젝트 구조

```
dream_diary/
├── README.md           # 이 파일
├── requirements.txt    # BE 파이썬 의존성
├── .env                # 환경 변수 (git 미추적)
├── venv/               # 파이썬 가상환경 (git 미추적)
├── BE/                 # FastAPI 백엔드
│   ├── app/
│   └── prisma/
└── FE/                 # Flutter 프론트엔드
```

설정·패키지·가상환경은 루트에서 일원화해 관리한다. `.env`는 python-dotenv가 실행 위치 상위 폴더에서 자동 탐색하므로 루트에 두어도 BE에서 인식된다.

단 **Prisma CLI는 상위 폴더를 탐색하지 않는다.** `./.env`와 `./prisma/.env`만 보므로 `prisma migrate` 계열은 루트에서 실행해야 한다 (아래 [배포](#배포-neon--render) 참고).

## 최초 설치

### BE
```bash
# 루트에서 가상환경 생성
python -m venv venv

# 가상환경 활성화
venv\Scripts\activate        # Windows
source venv/bin/activate     # macOS / Linux

# 의존성 설치
pip install -r requirements.txt

# Prisma 클라이언트 생성 (venv를 새로 만들 때마다 필요)
cd BE
PYTHONUTF8=1 prisma generate
```

Windows PowerShell에서는 마지막 줄을 이렇게 쓴다:
```powershell
$env:PYTHONUTF8 = "1"; prisma generate
```
`PYTHONUTF8` 없이 실행하면 `schema.prisma`의 한글 주석을 cp949로 쓰려다 `UnicodeEncodeError`가 나면서 클라이언트 생성이 중간에 깨진다.

라이브러리 인식이 안 될 때 (VS Code):
1. `Ctrl + Shift + P`
2. `Python: Select Interpreter` 검색
3. `.\venv\Scripts\python.exe` 선택

### FE
```bash
cd FE
flutter pub get
```

## 환경 변수 (`.env`)

루트의 `.env` 한 곳에서 관리한다. git 미추적이라 새로 클론했다면 직접 만들어야 한다.

| 키 | 용도 | 바꿔야 할 값 |
|---|---|---|
| `DATABASE_URL` | PostgreSQL 접속 문자열 | 로컬 개발과 배포에서 값이 다르다 (아래 참고) |
| `GEMINI_API_KEY` | 채팅 해몽·일기 생성·임베딩 (langchain이 자동 인식) | Google AI Studio 발급 키 |
| `FLUX_API_KEY` | 꿈 이미지 생성 | FLUX 발급 키 |
| `JWT_SECRET_KEY` | 액세스/리프레시 토큰 서명 | 임의의 긴 난수 문자열 |
| `S3_ENDPOINT` | 스토리지 S3 엔드포인트 | `https://<project_ref>.storage.supabase.co/storage/v1/s3` |
| `S3_ACCESS_KEY_ID` | S3 액세스 키 | Supabase → Project Settings → Storage → S3 access keys |
| `S3_SECRET_ACCESS_KEY` | S3 시크릿 키 | 위와 동일 |
| `S3_BUCKET` | 버킷 이름 | 예: `dream-images` |
| `S3_REGION` | 버킷 리전 | 예: `ap-southeast-1` |
| `S3_PUBLIC_BASE_URL` | 이미지 공개 URL 앞부분 (**버킷명까지 포함**) | `https://<project_ref>.supabase.co/storage/v1/object/public/dream-images` |

생성 이미지는 Supabase Storage에 올린다. `S3_*`는 S3 호환 규격이라 엔드포인트·리전만 바꾸면 Cloudflare R2나 AWS S3에서도 코드 수정 없이 동작한다.

`SERVER_BASE_URL`은 이 이관 이후 코드에서 읽지 않는다. 남겨두어도 무해하다.

`DATABASE_URL`은 개발 위치에 따라 갈아끼운다:

```bash
# 로컬 PostgreSQL
DATABASE_URL="postgresql://dreamdiary:비밀번호@localhost:5432/dream_diary?schema=public"

# 배포 (Neon)
DATABASE_URL="postgresql://neondb_owner:비밀번호@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require"
```

Neon 연결 문자열 주의사항:
- **`-pooler`가 없는 direct 호스트**를 쓴다. pgbouncer를 경유하면 Prisma의 prepared statement가 깨진다.
- 문자열 끝에 `&channel_binding=require`가 붙어 있으면 지운다. Prisma 엔진이 인식하지 못해 연결에 실패할 수 있다.

## 실행

### BE 로컬 서버
```bash
venv\Scripts\activate   # (또는 source venv/bin/activate)
cd BE
uvicorn app.main:app --reload
```

### BE 외부 접속 (안드로이드 연동)
```bash
cd BE
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### FE
```bash
cd FE
flutter run
```

## 배포 (Neon + Render)

**AWS EC2는 종료됐다.** 기존의 EC2 직접 운용(`nohup uvicorn ... &` + `lsof`/`kill`로 프로세스 관리, nginx 리버스 프록시) 방식은 더 이상 쓰지 않는다. 현재 구성은 다음과 같다.

| 계층 | 서비스 | 비고 |
|---|---|---|
| DB | Neon (무료) | PostgreSQL 18 + pgvector 0.8.x |
| 앱 | Render 무료 웹 서비스 | 루트의 `render.yaml` Blueprint |
| TLS·프록시 | Render 기본 제공 | **nginx 불필요** |

### 1. DB (Neon)

1. Neon 프로젝트를 만든다. 리전은 Render와 맞춘다 (현재 `ap-southeast-1` / Singapore).
2. `.env`의 `DATABASE_URL`을 Neon direct 문자열로 교체한다.
3. **루트에서** 마이그레이션을 적용한다. `BE/`에서 실행하면 Prisma CLI가 `.env`를 못 찾아 `P1012 Environment variable not found: DATABASE_URL`이 난다.

```bash
cd C:\dev\dream_diary
venv\Scripts\activate
prisma migrate deploy --schema=BE/prisma/schema.prisma
```

마이그레이션 첫 줄이 `CREATE EXTENSION IF NOT EXISTS vector;`라서 pgvector 확장도 함께 설치된다. 별도로 SQL을 실행할 필요는 없다.

### 2. 앱 (Render)

Render 대시보드 → **New → Blueprint** → 이 레포 선택. 루트의 `render.yaml`을 읽어 아래 설정이 자동 적용된다.

- 빌드: `pip install -r requirements.txt && cd BE && prisma generate`
- 시작: `cd BE && uvicorn app.main:app --host 0.0.0.0 --port $PORT`

환경 변수 5개(`DATABASE_URL`, `GEMINI_API_KEY`, `FLUX_API_KEY`, `JWT_SECRET_KEY`, `SERVER_BASE_URL`)는 `sync: false`라 대시보드에서 직접 입력해야 한다. 첫 배포 후 실제 서비스 URL을 확인해 `SERVER_BASE_URL`을 갱신하고 재배포한다.

### 3. 프론트엔드 연동

배포 주소가 바뀌면 FE의 하드코딩된 옛 EC2 IP(`13.209.97.107`)도 함께 정리해야 한다.

- `FE/lib/config/api.dart` — `baseUrl` 기본값
- `FE/lib/screens/` 아래 이미지 URL 보정 코드 (`dream_list_screen.dart`, `home_screen.dart`, `store_detail_screen.dart`, `store_screen.dart`)
- HTTPS로 전환되므로 `FE/android/app/src/main/AndroidManifest.xml`의 `usesCleartextTraffic="true"`는 제거해도 된다.

### 무료 티어 제약

- **Render**: 15분 무활동 시 슬립(콜드 스타트 수십 초), 영구 디스크 없음. 생성 이미지는 Supabase Storage에 올리므로 재배포와 무관하게 유지된다. 로컬 디스크에 남는 건 git 추적 파일인 상점 이미지뿐이다.
- **Neon**: 5분 유휴 시 자동 정지, 스토리지 0.5GB.
- **Supabase Storage**: 무료 1GB(이미지 1장 약 1.2MB 기준 800장 남짓). 프로젝트가 1주일 무활동 시 일시정지되므로 장기 방치에 주의.
- 슬립 방지는 외부 cron(cron-job.org 등)으로 `/`를 **4분 간격** 호출한다. Render(15분)보다 Neon(5분)이 먼저 정지하므로 주기를 여기에 맞춘다.
