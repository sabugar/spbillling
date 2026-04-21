from datetime import date
from decimal import Decimal
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.audit import AuditAction
from app.models.bill import Bill, PaymentMode
from app.models.cheque import Cheque, ChequeStatus
from app.models.customer import Customer
from app.models.payment import Payment, PaymentStatus
from app.schemas.payment import ChequeStatusUpdate, PaymentCreate, PaymentUpdate
from app.utils.audit import write_audit

TWO = Decimal("0.01")


def _next_payment_number(db: Session, pay_date: date) -> str:
    prefix = f"PAY/{pay_date.strftime('%Y%m')}/"
    max_num = db.scalar(
        select(func.max(Payment.payment_number)).where(Payment.payment_number.like(f"{prefix}%"))
    )
    next_seq = 1
    if max_num:
        try:
            next_seq = int(max_num.rsplit("/", 1)[1]) + 1
        except (ValueError, IndexError):
            next_seq = 1
    return f"{prefix}{next_seq:04d}"


def create_payment(db: Session, payload: PaymentCreate, user_id: int) -> Payment:
    customer = db.get(Customer, payload.customer_id)
    if not customer or customer.is_deleted:
        raise HTTPException(status_code=400, detail="Customer not found")

    pay_date = payload.payment_date or date.today()
    amount = Decimal(payload.amount).quantize(TWO)

    if payload.reference_bill_id:
        bill = db.get(Bill, payload.reference_bill_id)
        if not bill or bill.customer_id != customer.id:
            raise HTTPException(status_code=400, detail="Bill not found for this customer")
        bill.amount_paid = (Decimal(bill.amount_paid) + amount).quantize(TWO)
        bill.balance_due = (Decimal(bill.total_amount) - Decimal(bill.amount_paid)).quantize(TWO)

    status = PaymentStatus.CLEARED
    if payload.payment_mode == PaymentMode.CHEQUE:
        status = PaymentStatus.PENDING

    payment = Payment(
        payment_number=_next_payment_number(db, pay_date),
        payment_date=pay_date,
        customer_id=customer.id,
        reference_bill_id=payload.reference_bill_id,
        amount=amount,
        payment_mode=payload.payment_mode,
        cheque_details=payload.cheque_details.model_dump(mode="json") if payload.cheque_details else None,
        notes=payload.notes,
        status=status,
        created_by_id=user_id,
    )
    db.add(payment)
    db.flush()

    if status == PaymentStatus.CLEARED:
        customer.current_balance = (customer.current_balance - amount).quantize(TWO)

    if payload.payment_mode == PaymentMode.CHEQUE and payload.cheque_details:
        db.add(Cheque(
            cheque_number=payload.cheque_details.cheque_number,
            bank_name=payload.cheque_details.bank_name,
            branch_name=payload.cheque_details.branch_name,
            cheque_date=payload.cheque_details.cheque_date,
            amount=amount,
            customer_id=customer.id,
            payment_id=payment.id,
            status=ChequeStatus.PENDING,
            created_by_id=user_id,
        ))

    write_audit(db, entity_type="payment", entity_id=payment.id,
                action=AuditAction.CREATE, user_id=user_id,
                changes={"amount": str(amount), "mode": payload.payment_mode.value})
    db.commit()
    db.refresh(payment)
    return payment


def get_payment(db: Session, payment_id: int) -> Payment:
    p = db.get(Payment, payment_id)
    if not p:
        raise HTTPException(status_code=404, detail="Payment not found")
    return p


def list_payments(db: Session, *, customer_id: Optional[int] = None,
                  from_date: Optional[date] = None, to_date: Optional[date] = None):
    stmt = select(Payment).order_by(Payment.payment_date.desc(), Payment.id.desc())
    if customer_id:
        stmt = stmt.where(Payment.customer_id == customer_id)
    if from_date:
        stmt = stmt.where(Payment.payment_date >= from_date)
    if to_date:
        stmt = stmt.where(Payment.payment_date <= to_date)
    return stmt


def update_payment(db: Session, payment_id: int, payload: PaymentUpdate, user_id: int) -> Payment:
    p = get_payment(db, payment_id)
    customer = db.get(Customer, p.customer_id)
    old_status = p.status
    data = payload.model_dump(exclude_unset=True)

    if "status" in data and data["status"] != old_status:
        new_status = data["status"]
        # status transitions affecting customer balance
        if old_status != PaymentStatus.CLEARED and new_status == PaymentStatus.CLEARED:
            customer.current_balance = (customer.current_balance - p.amount).quantize(TWO)
        elif old_status == PaymentStatus.CLEARED and new_status != PaymentStatus.CLEARED:
            customer.current_balance = (customer.current_balance + p.amount).quantize(TWO)
        p.status = new_status

    if "notes" in data:
        p.notes = data["notes"]

    write_audit(db, entity_type="payment", entity_id=p.id,
                action=AuditAction.UPDATE, user_id=user_id,
                changes={"old_status": old_status.value, "new_status": p.status.value})
    db.commit()
    db.refresh(p)
    return p


def delete_payment(db: Session, payment_id: int, user_id: int) -> None:
    p = get_payment(db, payment_id)
    customer = db.get(Customer, p.customer_id)
    if p.status == PaymentStatus.CLEARED:
        customer.current_balance = (customer.current_balance + p.amount).quantize(TWO)
    if p.reference_bill_id:
        bill = db.get(Bill, p.reference_bill_id)
        if bill:
            bill.amount_paid = (Decimal(bill.amount_paid) - p.amount).quantize(TWO)
            bill.balance_due = (Decimal(bill.total_amount) - Decimal(bill.amount_paid)).quantize(TWO)
    db.delete(p)
    write_audit(db, entity_type="payment", entity_id=payment_id,
                action=AuditAction.DELETE, user_id=user_id)
    db.commit()


# ---------- Cheques ----------
def list_cheques(db: Session, *, status: Optional[ChequeStatus] = None,
                 from_date: Optional[date] = None, to_date: Optional[date] = None):
    stmt = select(Cheque).order_by(Cheque.cheque_date.desc())
    if status:
        stmt = stmt.where(Cheque.status == status)
    if from_date:
        stmt = stmt.where(Cheque.cheque_date >= from_date)
    if to_date:
        stmt = stmt.where(Cheque.cheque_date <= to_date)
    return stmt


def update_cheque_status(db: Session, cheque_id: int, payload: ChequeStatusUpdate, user_id: int) -> Cheque:
    cheque = db.get(Cheque, cheque_id)
    if not cheque:
        raise HTTPException(status_code=404, detail="Cheque not found")

    old_status = cheque.status
    cheque.status = payload.status
    cheque.cleared_date = payload.cleared_date
    cheque.bounce_reason = payload.bounce_reason

    # propagate to payment + customer balance
    if cheque.payment_id:
        pay = db.get(Payment, cheque.payment_id)
        if pay:
            customer = db.get(Customer, pay.customer_id)
            if old_status == ChequeStatus.PENDING and payload.status == ChequeStatus.CLEARED:
                pay.status = PaymentStatus.CLEARED
                customer.current_balance = (customer.current_balance - pay.amount).quantize(TWO)
            elif old_status == ChequeStatus.PENDING and payload.status == ChequeStatus.BOUNCED:
                pay.status = PaymentStatus.BOUNCED

    write_audit(db, entity_type="cheque", entity_id=cheque.id,
                action=AuditAction.UPDATE, user_id=user_id,
                changes={"old_status": old_status.value, "new_status": payload.status.value})
    db.commit()
    db.refresh(cheque)
    return cheque
