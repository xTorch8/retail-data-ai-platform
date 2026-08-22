import base64
from ..config import get_config
from cryptography.fernet import Fernet
from datetime import datetime, timedelta, timezone
import hashlib
import jwt
import logging
from ..models.auth_model import LoginRequest, LoginResponse

def _get_fernet() -> Fernet:
    config = get_config()
    secret_key = config.get("JWT_SECRET_KEY")
    derived_key = hashlib.sha256(secret_key.encode()).digest()
    fernet_key = base64.urlsafe_b64encode(derived_key)
    return Fernet(fernet_key)

def create_access_token(request: LoginRequest) -> LoginResponse:
    logging.info("[INFO][jwt_utils.py][create_access_token] Creating access token")
    try:
        config = get_config()
        fernet = _get_fernet()

        encrypted_password = fernet.encrypt(request.password.encode()).decode()

        expire = datetime.now(timezone.utc) + timedelta(minutes = config.get("JWT_TOKEN_EXPIRE_MINUTES"))
        payload = {
            "sub": request.username,
            "pwd": encrypted_password,
            "exp": expire
        }

        token = jwt.encode(payload, config.get("JWT_SECRET_KEY"), algorithm = "HS256")
        return LoginResponse(access_token = token)
    except Exception as e:
        logging.error(f"[ERROR][jwt_utils.py][create_access_token] Error creating access token: {e}")
        return None

def decode_access_token(token: str) -> LoginRequest:
    logging.info("[INFO][jwt_utils.py][decode_access_token] Decoding access token")
    try:
        config = get_config()
        fernet = _get_fernet()

        payload = jwt.decode(token, config.get("JWT_SECRET_KEY"), algorithms = ["HS256"])

        username = payload.get("sub")
        decrypted_password = fernet.decrypt(payload.get("pwd").encode()).decode()

        return LoginRequest(username = username, password = decrypted_password)
    except Exception as e:
        logging.error(f"[ERROR][jwt_utils.py][decode_access_token] Error decoding access token: {e}")
        return None
