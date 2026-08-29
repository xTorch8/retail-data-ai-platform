from enum import Enum
from .openai_model import OpenAIModelTier
from pydantic import BaseModel
from .query_model import ExecuteSQLQueryResponse
from typing import List, Optional

class ChatMessageRole(Enum):
    USER = 1
    ASSISTANT = 2
    TOOL = 3

class ChatMessage(BaseModel):
    role: ChatMessageRole
    content: str
    name: Optional[str] = None
    tool_call_id: Optional[str] = None
    tool_calls: Optional[List[dict]] = None

class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = None
    model_tier: Optional[OpenAIModelTier] = None

class ChatResponse(BaseModel):
    message: str
    sql: Optional[str] = None
    query_result: Optional[ExecuteSQLQueryResponse] = None
    agent_messages: Optional[List[ChatMessage]] = None