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