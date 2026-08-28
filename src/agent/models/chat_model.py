from pydantic import BaseModel
from .query_model import ExecuteSQLQueryResponse
from typing import Optional

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    message: str
    sql: Optional[str] = None
    query_result: Optional[ExecuteSQLQueryResponse] = None