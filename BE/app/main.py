from fastapi import FastAPI
from dotenv import load_dotenv
from app.core.db import db
from fastapi.staticfiles import StaticFiles
from app.api import userApi, chatApi, chatSessionApi,storeApi,reportApi
from contextlib import asynccontextmanager

load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # 서버가 켜질 때 실행
    # 여기서 예외가 나면 기동이 중단돼 "/" 헬스체크까지 막히고 배포 자체가 실패한다.
    # DB가 죽어도 앱은 뜨게 두고, DB를 쓰는 엔드포인트만 실패하도록 한다.
    try:
        await db.connect()
        print("DB 연결 성공")
    except Exception as e:
        print(f"DB 연결 실패 (앱은 기동함): {e}")

    yield # 여기서 서버가 돌아가며 요청을 처리함

    # 서버가 꺼질 때 실행
    if db.is_connected():
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
app.include_router(reportApi.router,prefix="/report",tags=["Chat"])
app.include_router(storeApi.router,prefix="/item",tags=["Store"])