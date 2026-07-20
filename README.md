# Re-view

창업캡스톤디자인2 — 꿈 일기 풀스택 프로젝트

- **BE**: FastAPI + Prisma (PostgreSQL) — `BE/`
- **FE**: Flutter — `FE/`

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
```

라이브러리 인식이 안 될 때 (VS Code):
1. `Ctrl + Shift + P`
2. `Python: Select Interpreter` 검색
3. `.\venv\Scripts\python.exe` 선택

### FE
```bash
cd FE
flutter pub get
```

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

## 서버 배포용

```bash
source venv/bin/activate
cd BE

# 실행
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 &

# 서버 끄기
lsof -i :8000
kill -9 [PID번호]
```
