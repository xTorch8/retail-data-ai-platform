from enum import Enum
from .openai_model import OpenAIModelTier
from pydantic import BaseModel
from .query_model import ExecuteSQLQueryResponse
from typing import List, Optional

class ChatMessageRole(Enum):
    USER = 1
    ASSISTANT = 2

class ChatMessage(BaseModel):
    role: ChatMessageRole
    content: str

class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = None
    model_tier: Optional[OpenAIModelTier] = None

class ChatResponse(BaseModel):
    message: str
    sql: Optional[str] = None
    query_result: Optional[ExecuteSQLQueryResponse] = None