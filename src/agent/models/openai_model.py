from enum import IntEnum
from pydantic import BaseModel
from typing import List, Optional

class OpenAIModelTier(IntEnum):
    SMALL = 1
    MEDIUM = 2 
    LARGE = 3

class GetOpenAIModelRequest(BaseModel):
    tier: OpenAIModelTier

class GetOpenAIResponseRequest(BaseModel):
    input: List[str]
    model_tier: OpenAIModelTier
    store: Optional[bool] = False