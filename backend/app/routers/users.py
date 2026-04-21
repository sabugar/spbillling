from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.user import User
from app.schemas.common import APIResponse, PaginatedResponse
from app.schemas.user import UserCreate, UserOut, UserUpdate
from app.services import user_service
from app.utils.auth import require_admin
from app.utils.pagination import paginate

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("", response_model=PaginatedResponse[UserOut])
def list_users(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    stmt = user_service.list_users(db)
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=UserOut)


@router.post("", response_model=APIResponse[UserOut])
def create_user(payload: UserCreate, db: Session = Depends(get_db),
                admin: User = Depends(require_admin)):
    u = user_service.create_user(db, payload, admin.id)
    return APIResponse(data=UserOut.model_validate(u), message="User created")


@router.get("/{user_id}", response_model=APIResponse[UserOut])
def get_user(user_id: int, db: Session = Depends(get_db),
             _admin: User = Depends(require_admin)):
    return APIResponse(data=UserOut.model_validate(user_service.get_user(db, user_id)))


@router.put("/{user_id}", response_model=APIResponse[UserOut])
def update_user(user_id: int, payload: UserUpdate, db: Session = Depends(get_db),
                admin: User = Depends(require_admin)):
    u = user_service.update_user(db, user_id, payload, admin.id)
    return APIResponse(data=UserOut.model_validate(u), message="User updated")


@router.delete("/{user_id}", response_model=APIResponse)
def deactivate_user(user_id: int, db: Session = Depends(get_db),
                    admin: User = Depends(require_admin)):
    user_service.deactivate_user(db, user_id, admin.id)
    return APIResponse(message="User deactivated")
