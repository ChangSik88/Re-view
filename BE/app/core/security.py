import jwt,os,bcrypt
from datetime import datetime, timedelta
from dotenv import load_dotenv
load_dotenv()

# .env에서 비밀키를 가져옵니다. (없으면 에러를 띄워 개발자에게 알림)
SECRET_KEY = os.getenv("JWT_SECRET_KEY")
if not SECRET_KEY:
    raise ValueError("환경 변수( .env )에 JWT_SECRET_KEY가 설정되지 않았습니다")
ALGORITHM = "HS256"

def create_access_token(user_id: int):
    # 토큰 탈취 시 노출 창을 줄이기 위해 유효기간을 7일로 제한합니다.
    # (refresh 토큰 도입 시 이 값을 더 짧게 조정할 수 있습니다.)
    expire = datetime.now() + timedelta(days=7)
    
    # 토큰 안에 담을 내용 (sub: 유저 고유 ID, exp: 만료 시간)
    payload = {
        "sub": str(user_id),
        "exp": expire
    }
    
    # 비밀 키로 도장을 찍어 암호화된 토큰 문자열을 반환합니다.
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def hash_password(plain_password: str) -> str:
    # 평문 비밀번호를 bcrypt 해시 문자열로 변환합니다.
    # bcrypt는 72바이트 초과 입력에 ValueError를 던진다. 한글은 1글자=3바이트라
    # 30자 제한(userSchema)만으로는 통과해도 여기서 터질 수 있어 바이트 단위로 자른다.
    hashed = bcrypt.hashpw(plain_password.encode("utf-8")[:72], bcrypt.gensalt())
    return hashed.decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    # 평문 비밀번호가 저장된 해시와 일치하는지 검증합니다.
    # hash_password와 동일하게 72바이트로 잘라야 긴 비밀번호도 검증이 일치한다.
    return bcrypt.checkpw(plain_password.encode("utf-8")[:72], hashed_password.encode("utf-8"))