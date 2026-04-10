# Re-view

창업캡스톤디자인2 BE

# 가상환경 비활성화

deactivate

# 가상환경 활성화

venv\Scripts\activate

# 필요한 라이브러리 설치

1. 가상환경 활성화
2. pip install -r requirements.txt

\* 라이브러리 인식이 안된다면?

1. Ctrl + shift + p
2. Python: Select Interpreter 검색
3. Python~~(venv) 혹은 .\venv\Scripts\python.exe 선택

# 로컬 서버 실행

uvicorn app.main:app --reload
