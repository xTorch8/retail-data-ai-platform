import logging
import requests
from ..config import get_config

class ChatService:
    def __init__(self):
        self._config = get_config()

    def chat(self, token, message, history):
        logging.info("[INFO][chat_service.py][chat] Sending chat request to API")
        url = f"{self._config.get('API_BASE_URL')}/api/chat"
        
        api_history = []
        for msg in history:
            role_str = msg.get("role")
            content = msg.get("content")
            if isinstance(content, list):
                text_parts = []
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "text":
                        text_parts.append(part.get("text", ""))
                    elif isinstance(part, str):
                        text_parts.append(part)
                content = "".join(text_parts)
            elif isinstance(content, dict):
                content = content.get("text", "")
            else:
                content = str(content)

            if role_str == "user":
                role_val = 1
            elif role_str == "assistant":
                role_val = 2
            else:
                role_val = 3
                
            api_history.append({
                "role": role_val,
                "content": content
            })

        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "message": message,
            "history": api_history
        }

        try:
            response = requests.post(
                url,
                headers = headers,
                json = payload,
                timeout = 60.0
            )
            
            if response.status_code == 200:
                response_json = response.json()
                if not response_json.get("is_success", True):
                    error_msg = response_json.get("error", "Unknown API error")
                    logging.warning(f"[WARNING][chat_service.py][chat] Chat response indicated failure: {error_msg}")
                    raise Exception(error_msg)
                
                logging.info("[INFO][chat_service.py][chat] Chat request successful")
                return response_json
            else:
                try:
                    error_detail = response.json().get("detail", "Error communicating with AI agent")
                except Exception:
                    error_detail = response.text or "Error communicating with AI agent"
                logging.warning(f"[WARNING][chat_service.py][chat] Chat request failed: {error_detail}")
                raise Exception(error_detail)
        except requests.RequestException as e:
            logging.error(f"[ERROR][chat_service.py][chat] Network error: {e}")
            raise Exception("Cannot connect to chat server")
        except Exception as e:
            logging.error(f"[ERROR][chat_service.py][chat] Unexpected error: {e}")
            raise

