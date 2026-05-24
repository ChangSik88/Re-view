# Re-view

창업캡스톤디자인2 BE

# 가상환경 비활성화

deactivate

# 가상환경 활성화

venv\Scripts\activate
source venv/bin/activate

# 필요한 라이브러리 설치

1. 가상환경 활성화
2. pip install -r requirements.txt

\* 라이브러리 인식이 안된다면?

1. Ctrl + shift + p
2. Python: Select Interpreter 검색
3. Python~~(venv) 혹은 .\venv\Scripts\python.exe 선택

# 로컬 서버 실행

uvicorn app.main:app --reload

# 안드로이드 서버 접속

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload


# 서버용
## 실행
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 &

## 가상환경 활성화
source venv/bin/activate

## 서버 끄기
lsof -i :8000
kill -9 [PID번호]