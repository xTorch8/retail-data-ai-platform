from ..dependencies.snowflake_dependency import get_snowflake_root_dependency 
from fastapi import APIRouter, Depends
from ..models.chat_model import ChatRequest
from ..services.chat_service import ChatService
from snowflake.core import Root

router = APIRouter(
    prefix = "/api/chat",
    tags = ["chat"]
)

chat_service = ChatService()

@router.post("")
async def chat(request: ChatRequest, root: Root = Depends(get_snowflake_root_dependency)):
    return chat_service.chat(root, request)

