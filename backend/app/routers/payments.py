from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.cheque import ChequeStatus
from app.models.user import User
from app.schemas.common import APIResponse, PaginatedResponse
from app.schemas.payment import (
    ChequeOut, ChequeStatusUpdate, PaymentCreate, PaymentOut, PaymentUpdate,
)
from app.services import payment_service
from app.utils.auth import get_current_user, require_admin, require_staff
from app.utils.pagination import paginate

router = APIRouter(prefix="/payments", tags=["Payments"])


@router.get("", response_model=PaginatedResponse[PaymentOut])
def list_payments(
    customer_id: Optional[int] = None,
    from_date: Optional[date] = Query(None, alias="from"),
    to_date: Optional[date] = Query(None, alias="to"),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    stmt = payment_service.list_payments(db, customer_id=customer_id,
                                          from_date=from_date, to_date=to_date)
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=PaymentOut)


@router.post("", response_model=APIResponse[PaymentOut])
def create_payment(payload: PaymentCreate, db: Session = Depends(get_db),
                   user: User = Depends(require_staff)):
    p = payment_service.create_payment(db, payload, user.id)
    return APIResponse(data=PaymentOut.model_validate(p), message="Payment recorded")


@router.get("/{payment_id}", response_model=APIResponse[PaymentOut])
def get_payment(payment_id: int, db: Session = Depends(get_db),
                _user: User = Depends(get_current_user)):
    p = payment_service.get_payment(db, payment_id)
    return APIResponse(data=PaymentOut.model_validate(p))


@router.put("/{payment_id}", response_model=APIResponse[PaymentOut])
def update_payment(payment_id: int, payload: PaymentUpdate,
                   db: Session = Depends(get_db), user: User = Depends(require_staff)):
    p = payment_service.update_payment(db, payment_id, payload, user.id)
    return APIResponse(data=PaymentOut.model_validate(p), message="Payment updated")


@router.delete("/{payment_id}", response_model=APIResponse)
def delete_payment(payment_id: int, db: Session = Depends(get_db),
                   user: User = Depends(require_admin)):
    payment_service.delete_payment(db, payment_id, user.id)
    return APIResponse(message="Payment deleted")
