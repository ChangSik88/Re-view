import jwt,os
from datetime import datetime, timedelta
from dotenv import load_dotenv
load_dotenv()

# .env에서 비밀키를 가져옵니다. (없으면 에러를 띄워 개발자에게 알림)
SECRET_KEY = os.getenv("JWT_SECRET_KEY")
if not SECRET_KEY:
    raise ValueError("환경 변수( .env )에 JWT_SECRET_KEY가 설정되지 않았습니다")
ALGORITHM = "HS256"

def create_access_token(user_id: int):
    # 테스트 편의성을 위해 토큰 유효기간을 넉넉하게 30일로 잡습니다.
    expire = datetime.now() + timedelta(days=30)
    
    # 토큰 안에 담을 내용 (sub: 유저 고유 ID, exp: 만료 시간)
    payload = {
        "sub": str(user_id),
        "exp": expire
    }
    
    # 비밀 키로 도장을 찍어 암호화된 토큰 문자열을 반환합니다.
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)