from ..config import get_config
from ..models.snowflake_model import GetSnowflakeRootRequest
import logging
from snowflake.core import Root
from snowflake.snowpark import Session

def get_snowflake_root(request: GetSnowflakeRootRequest) -> Root:
    logging.info("[INFO][snowflake_client.py][get_snowflake_root] Creating Snowflake root")
    try:
        config = get_config()
        session_parameter = {
            "account": config.get("SNOWFLAKE_ACCOUNT"),
            "user": request.username,
            "password": request.password,
            "role": config.get("SNOWFLAKE_ROLE"),
            "database": config.get("SNOWFLAKE_DATABASE"),
            "warehouse": config.get("SNOWFLAKE_WAREHOUSE"),
            "schema": config.get("SNOWFLAKE_SCHEMA")
        }

        session = Session.builder.configs(session_parameter).create()
        root = Root(session)
        return root
    except Exception as e:
        logging.error(f"[ERROR][snowflake_client.py][get_snowflake_root] Error creating Snowflake root: {e}")
        return None