import logging
import requests
from ..config import get_config

class AuthService:
    def __init__(self):
        self._config = get_config()

    def login(self, username, password):
        logging.info("[INFO][auth_service.py][login] Sending login request to API")
        url = f"{self._config.get('API_BASE_URL')}/api/auth/login"
        try:
            # OAuth2PasswordRequestForm expects form-encoded fields
            response = requests.post(
                url,
                data = {
                    "username": username,
                    "password": password
                },
                timeout = 10.0
            )
            
            if response.status_code == 200:
                logging.info("[INFO][auth_service.py][login] Login successful")
                return response.json()
            else:
                try:
                    error_detail = response.json().get("detail", "Invalid username or password")
                except Exception:
                    error_detail = response.text or "Invalid username or password"
                logging.warning(f"[WARNING][auth_service.py][login] Login failed: {error_detail}")
                raise Exception(error_detail)
        except requests.RequestException as e:
            logging.error(f"[ERROR][auth_service.py][login] Network error: {e}")
            raise Exception("Cannot connect to authentication server")
        except Exception as e:
            logging.error(f"[ERROR][auth_service.py][login] Unexpected error: {e}")
            raise

