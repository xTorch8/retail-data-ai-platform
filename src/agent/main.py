from .controllers.auth_controller import router as auth_router
from fastapi import FastAPI
import logging
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
LOG_DIR = BASE_DIR / "logs"

logging.basicConfig(
    filename = LOG_DIR / "app.log",
    filemode = "a",
    format = "%(asctime)s - %(levelname)s - %(message)s"
)

app = FastAPI()
app.include_router(auth_router)

@app.get("/")
async def root():
    return {"message": "Welcome to the API"}