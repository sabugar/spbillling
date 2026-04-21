from typing import Optional

from pydantic import BaseModel, Field

from app.models.user import UserRole


class LoginRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=64)
    password: str = Field(..., min_length=4, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: UserRole
    user_id: int
    full_name: str


class CurrentUser(BaseModel):
    id: int
    username: str
    full_name: str
    role: UserRole
    email: Optional[str] = None
    is_active: bool
