from ..config import get_config
from ..models.openai_model import (
    GetOpenAIModelRequest,
    OpenAIModelTier,
)
from langchain_openai import ChatOpenAI
import logging
from typing import Optional

def get_openai_model(request: GetOpenAIModelRequest) -> Optional[str]:
    logging.info("[INFO][openai_client.py][get_openai_model] Getting OpenAI model")
    try:
        config = get_config()
        if request.tier == OpenAIModelTier.SMALL or request.tier is None:
            model = config.get("OPENAI_SMALL_MODEL")
        elif request.tier == OpenAIModelTier.MEDIUM:
            model = config.get("OPENAI_MEDIUM_MODEL")
        elif request.tier == OpenAIModelTier.LARGE:
            model = config.get("OPENAI_LARGE_MODEL")

        return model

    except Exception as e:
        logging.error(f"[ERROR][openai_client.py][get_openai_model] Error getting OpenAI model: {e}")
        return None


def get_openai_client(request: GetOpenAIModelRequest) -> Optional[ChatOpenAI]:
    logging.info("[INFO][openai_client.py][get_openai_client] Creating OpenAI LangChain client")
    try:
        config = get_config()
        api_key = config.get("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY is not configured")

        model = get_openai_model(request)
        client = ChatOpenAI(
            model = model,
            api_key = api_key,
        )

        return client

    except Exception as e:
        logging.error(f"[ERROR][openai_client.py][get_openai_client] Error creating OpenAI LangChain client: {e}")
        return None
