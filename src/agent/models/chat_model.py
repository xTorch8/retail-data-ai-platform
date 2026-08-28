from pydantic import BaseModel
from typing import Any, Optional

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    message: str
    sql: Optional[str] = None
    query_result: Optional[Any] = None