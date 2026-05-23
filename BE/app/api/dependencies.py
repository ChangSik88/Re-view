from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from app.core.security import SECRET_KEY, ALGORITHM

# 1. FastAPI의 내장 Bearer 토큰 처리기를 소환합니다.
security = HTTPBearer()

# 2. Header(None) 대신 Depends(security)를 사용합니다.
async def get_current_user_id(credentials: HTTPAuthorizationCredentials = Depends(security)) -> int:
    # HTTPBearer가 알아서 "Bearer "가 있는지 검사하고, 순수 토큰만 credentials.credentials에 담아줍니다!
    token = credentials.credentials
    
    try:
        # 토큰 해독 로직은 동일합니다.
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return int(payload.get("sub"))
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="토큰이 만료되었습니다.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")