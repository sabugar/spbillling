from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field

from app.models.bill import PaymentMode
from app.models.cheque import ChequeStatus
from app.models.payment import PaymentStatus
from app.schemas.bill import ChequeDetails


class PaymentCreate(BaseModel):
    customer_id: int
    payment_date: Optional[date] = None
    amount: Decimal = Field(..., gt=0)
    payment_mode: PaymentMode = PaymentMode.CASH
    reference_bill_id: Optional[int] = None
    cheque_details: Optional[ChequeDetails] = None
    notes: Optional[str] = None


class PaymentUpdate(BaseModel):
    status: Optional[PaymentStatus] = None
    notes: Optional[str] = None


class PaymentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    payment_number: str
    payment_date: date
    customer_id: int
    reference_bill_id: Optional[int] = None
    amount: Decimal
    payment_mode: PaymentMode
    cheque_details: Optional[dict] = None
    notes: Optional[str] = None
    status: PaymentStatus
    created_at: datetime


# ----- Cheque -----
class ChequeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    cheque_number: str
    bank_name: str
    branch_name: Optional[str] = None
    cheque_date: date
    amount: Decimal
    customer_id: Optional[int] = None
    bill_id: Optional[int] = None
    payment_id: Optional[int] = None
    status: ChequeStatus
    cleared_date: Optional[date] = None
    bounce_reason: Optional[str] = None
    created_at: datetime


class ChequeStatusUpdate(BaseModel):
    status: ChequeStatus
    cleared_date: Optional[date] = None
    bounce_reason: Optional[str] = None
