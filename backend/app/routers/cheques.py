from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.cheque import ChequeStatus
from app.models.user import User
from app.schemas.common import APIResponse, PaginatedResponse
from app.schemas.payment import ChequeOut, ChequeStatusUpdate
from app.services import payment_service
from app.utils.auth import get_current_user, require_staff
from app.utils.pagination import paginate

router = APIRouter(prefix="/cheques", tags=["Cheques"])


@router.get("", response_model=PaginatedResponse[ChequeOut])
def list_cheques(
    status: Optional[ChequeStatus] = None,
    from_date: Optional[date] = Query(None, alias="from"),
    to_date: Optional[date] = Query(None, alias="to"),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    stmt = payment_service.list_cheques(db, status=status, from_date=from_date, to_date=to_date)
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=ChequeOut)


@router.put("/{cheque_id}/status", response_model=APIResponse[ChequeOut])
def update_cheque_status(cheque_id: int, payload: ChequeStatusUpdate,
                         db: Session = Depends(get_db), user: User = Depends(require_staff)):
    c = payment_service.update_cheque_status(db, cheque_id, payload, user.id)
    return APIResponse(data=ChequeOut.model_validate(c), message="Cheque updated")
