from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class WeeklySessionDTO(BaseModel):
    content_id: int
    weekly_content: Optional[str]
    start_date: Optional[datetime]
    end_date: Optional[datetime]

class ReportResponse(BaseModel):
    message: str
    result: WeeklySessionDTO

class WeeklySessionDTO(BaseModel):
    content_id: int
    user_id: int
    weekly_content: str
    start_date: datetime
    end_date: datetime

class ReportGetResponse(BaseModel):
    message: str
    result: Optional[WeeklySessionDTO] = None