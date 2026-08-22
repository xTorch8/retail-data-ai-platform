from dotenv import load_dotenv
import logging
import os

def get_config():
    logging.info("[INFO][config.py][get_config] Loading configuration from .env file")
    try:
        load_dotenv()

        config = {
            "SNOWFLAKE_ACCOUNT": os.getenv("SNOWFLAKE_ACCOUNT"),
            "SNOWFLAKE_ROLE": os.getenv("SNOWFLAKE_ROLE"),
            "SNOWFLAKE_DATABASE": os.getenv("SNOWFLAKE_DATABASE"),
            "SNOWFLAKE_WAREHOUSE": os.getenv("SNOWFLAKE_WAREHOUSE"),
            "SNOWFLAKE_SCHEMA": os.getenv("SNOWFLAKE_SCHEMA"),

            "JWT_SECRET_KEY": os.getenv("JWT_SECRET_KEY"),
            "JWT_TOKEN_EXPIRE_MINUTES": int(os.getenv("JWT_TOKEN_EXPIRE_MINUTES", "60")),

            "OPENAI_API_KEY": os.getenv("OPENAI_API_KEY"),
            "OPENAI_SMALL_MODEL": os.getenv("OPENAI_SMALL_MODEL"),
            "OPENAI_MEDIUM_MODEL": os.getenv("OPENAI_MEDIUM_MODEL"),
            "OPENAI_LARGE_MODEL": os.getenv("OPENAI_LARGE_MODEL"),

        }

        return config
    except Exception as e:
        logging.error(f"[ERROR][config.py][get_config] Error loading configuration: {e}")
        return None
