from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.user import User
from app.schemas.common import APIResponse, PaginatedResponse
from app.schemas.distributor_outlet import DOCreate, DORead, DOSearchResult, DOUpdate
from app.services import distributor_outlet_service as svc
from app.utils.auth import get_current_user, require_admin
from app.utils.pagination import paginate

router = APIRouter(prefix="/distributor-outlets", tags=["Distributor Outlets"])


@router.get("", response_model=PaginatedResponse[DORead])
def list_outlets(
    q: Optional[str] = None,
    active: Optional[bool] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    stmt = svc.list_dos(db, q=q, active=active)
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=DORead)


@router.get("/search", response_model=APIResponse[list[DOSearchResult]])
def search_outlets(
    q: str = Query("", max_length=100),
    limit: int = Query(20, ge=1, le=50),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    rows = svc.search_dos(db, q, limit)
    return APIResponse(data=[DOSearchResult.model_validate(r) for r in rows])


@router.get("/{do_id}", response_model=APIResponse[DORead])
def get_outlet(
    do_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    do = svc.get_do(db, do_id)
    return APIResponse(data=DORead.model_validate(do))


@router.post("", response_model=APIResponse[DORead])
def create_outlet(
    payload: DOCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_admin),
):
    do = svc.create_do(db, payload, user.id)
    return APIResponse(data=DORead.model_validate(do), message="DO created")


@router.put("/{do_id}", response_model=APIResponse[DORead])
def update_outlet(
    do_id: int,
    payload: DOUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_admin),
):
    do = svc.update_do(db, do_id, payload, user.id)
    return APIResponse(data=DORead.model_validate(do), message="DO updated")


@router.patch("/{do_id}/active", response_model=APIResponse[DORead])
def set_active(
    do_id: int,
    active: bool = Query(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_admin),
):
    do = svc.set_active(db, do_id, active, user.id)
    return APIResponse(data=DORead.model_validate(do))


@router.delete("/{do_id}", response_model=APIResponse)
def delete_outlet(
    do_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(require_admin),
):
    svc.soft_delete_do(db, do_id, user.id)
    return APIResponse(message="DO deleted")
