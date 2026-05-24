from fastapi import FastAPI
from dotenv import load_dotenv
from app.core.db import db
from fastapi.staticfiles import StaticFiles
from app.api import userApi, chatApi, chatSessionApi,storeApi,reportApi
from contextlib import asynccontextmanager
import os

load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # 서버가 켜질 때 실행
    await db.connect()
    print("DB 연결 성공")
    
    yield # 여기서 서버가 돌아가며 요청을 처리함
    
    # 서버가 꺼질 때 실행
    await db.disconnect()
    print("DB 연결 종료")

app = FastAPI(lifespan=lifespan)

@app.get("/")
def read_root():
    return {"status": "success", "message": "서버가 정상적으로 시작되었습니다"}

app.mount("/static", StaticFiles(directory="app/static"), name="static")

app.include_router(userApi.router, prefix="/users", tags=["User"])
app.include_router(chatApi.router, prefix="/chatting", tags=["Chat"])
app.include_router(chatSessionApi.router, prefix="/chatting", tags=["Chat"])
app.include_router(storeApi.router,prefix="/item",tags=["Store"])
app.include_router(reportApi.router,prefix="/report",tags=["Chat"])