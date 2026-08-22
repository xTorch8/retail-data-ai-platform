from fastapi import APIRouter, Depends
from fastapi.security import OAuth2PasswordRequestForm
from ..models.auth_model import LoginRequest, LoginResponse
from ..services.auth_service import AuthService

router = APIRouter(
    prefix = "/api/auth",
    tags = ["auth"]
)

auth_service = AuthService()

@router.post("/login", response_model = LoginResponse)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    request = LoginRequest(
        username = form_data.username,
        password = form_data.password
    )
    return auth_service.login(request)
