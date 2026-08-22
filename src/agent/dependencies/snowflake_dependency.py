from ..clients.snowflake_client import get_snowflake_root
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
import logging
from ..models.snowflake_model import GetSnowflakeRootRequest
from snowflake.core import Root
from ..utils.jwt_utils import decode_access_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl = "/api/auth/login")

def get_snowflake_root_dependency(token: str = Depends(oauth2_scheme)) -> Root:
    logging.info("[INFO][snowflake_dependency.py][get_snowflake_root_dependency] Resolving Snowflake root from token")
    try:
        credentials = decode_access_token(token)
        if credentials is None:
            raise HTTPException(
                status_code = status.HTTP_401_UNAUTHORIZED,
                detail = "Invalid or expired token",
                headers = {"WWW-Authenticate": "Bearer"}
            )

        root = get_snowflake_root(GetSnowflakeRootRequest(
            username = credentials.username,
            password = credentials.password
        ))
        if root is None:
            raise HTTPException(
                status_code = status.HTTP_401_UNAUTHORIZED,
                detail = "Could not connect to Snowflake with provided credentials",
                headers = {"WWW-Authenticate": "Bearer"}
            )

        return root
    except Exception as e:
        logging.error(f"[ERROR][snowflake_dependency.py][get_snowflake_root_dependency] Unexpected error: {e}")
        raise HTTPException(
            status_code = status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail = "Internal server error while connecting to Snowflake"
        )
