from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.user import User
from app.schemas.auth import CurrentUser, LoginRequest, TokenResponse
from app.schemas.common import APIResponse
from app.services import auth_service
from app.utils.auth import get_current_user

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/login", response_model=APIResponse[TokenResponse])
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    token = auth_service.authenticate(db, payload)
    return APIResponse(data=token, message="Login successful")


@router.post("/logout", response_model=APIResponse)
def logout(_: User = Depends(get_current_user)):
    # Client-side token deletion — server is stateless
    return APIResponse(message="Logged out")


@router.get("/me", response_model=APIResponse[CurrentUser])
def me(user: User = Depends(get_current_user)):
    return APIResponse(data=CurrentUser.model_validate(user.__dict__))
