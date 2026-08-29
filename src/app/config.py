import os
from dotenv import load_dotenv

def get_config():
    load_dotenv()
    
    config = {
        "API_BASE_URL": os.getenv("API_BASE_URL"),
    }
    return config

