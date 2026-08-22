from ..models.auth_model import LoginRequest, LoginResponse
from ..clients.snowflake_client import get_snowflake_root
from ..utils.jwt_utils import create_access_token
import logging
from fastapi import HTTPException, status

class AuthService:
    def __init__(self):
        pass

    def login(self, request: LoginRequest) -> LoginResponse:
        logging.info("[INFO][auth_service.py][login] Processing login request")
        try:
            root = get_snowflake_root(request)
            if root is None:
                raise HTTPException(
                    status_code = status.HTTP_401_UNAUTHORIZED,
                    detail = "Invalid username or password"
                )

            token = create_access_token(request)
            return token
        except HTTPException:
            raise
        except Exception as e:
            logging.error(f"[ERROR][auth_service.py][login] Error during login: {e}")
            raise HTTPException(
                status_code = status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail = "Error during login"
            )
