from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field

from app.models.bill import BillStatus, PaymentMode
from app.schemas.distributor_outlet import DOSearchResult


class ChequeDetails(BaseModel):
    cheque_number: str
    bank_name: str
    branch_name: Optional[str] = None
    cheque_date: date


class BillItemCreate(BaseModel):
    product_variant_id: int
    quantity: int = Field(..., gt=0)
    rate: Optional[Decimal] = None       # optional override; defaults to variant price
    empty_returned: int = 0
    gst_rate: Optional[Decimal] = None   # optional override; defaults to variant GST


class BillCreate(BaseModel):
    customer_id: int
    bill_date: Optional[date] = None
    items: list[BillItemCreate] = Field(..., min_length=1)
    discount: Decimal = Decimal("0")
    payment_mode: PaymentMode = PaymentMode.CASH
    amount_paid: Decimal = Decimal("0")
    cheque_details: Optional[ChequeDetails] = None
    notes: Optional[str] = None


class BillUpdate(BaseModel):
    discount: Optional[Decimal] = None
    payment_mode: Optional[PaymentMode] = None
    amount_paid: Optional[Decimal] = None
    cheque_details: Optional[ChequeDetails] = None
    notes: Optional[str] = None


class BillItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_variant_id: int
    quantity: int
    rate: Decimal
    empty_returned: int
    gst_rate: Decimal
    gst_amount: Decimal
    line_total: Decimal


class BillOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    bill_number: str
    bill_date: date
    customer_id: int
    subtotal: Decimal
    discount: Decimal
    gst_amount: Decimal
    total_amount: Decimal
    amount_paid: Decimal
    balance_due: Decimal
    payment_mode: PaymentMode
    cheque_details: Optional[dict] = None
    notes: Optional[str] = None
    status: BillStatus
    items: list[BillItemOut] = []
    created_at: datetime
    updated_at: datetime


class BillCustomerMini(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    village: str
    consumer_number: str
    distributor_outlet: Optional[DOSearchResult] = None


class BillSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    bill_number: str
    bill_date: date
    customer_id: int
    customer: Optional[BillCustomerMini] = None
    total_amount: Decimal
    amount_paid: Decimal
    balance_due: Decimal
    status: BillStatus
