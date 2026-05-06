from fastapi import FastAPI
from dotenv import load_dotenv
from app.core.db import db
from app.api import userApi
from contextlib import asynccontextmanager
import os

load_dotenv()

app = FastAPI()

@app.get("/")
def read_root():
    return {"status": "success", "message": "서버가 정상적으로 시작되었습니다"}

@app.get("/items/{item_id}")
def read_item(item_id: int, q: str = None):
    return {"item_id": item_id, "q": q}

@asynccontextmanager
async def lifespan(app: FastAPI):
    #서버가 켜질 때 실행
    await db.connect()
    print("DB 연결 성공")
    
    yield # 여기서 서버가 돌아가며 요청을 처리함
    
    #서버가 꺼질 때 실행
    await db.disconnect()
    print("DB 연결 종료")

# 2. FastAPI 인스턴스 생성 시 lifespan 등록
app = FastAPI(lifespan=lifespan)

app.include_router(userApi.router, prefix="/users", tags=["User"])