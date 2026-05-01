from datetime import date
from decimal import Decimal
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session, selectinload

from app.config.settings import settings
from app.models.audit import AuditAction
from app.models.bill import Bill, BillItem, BillStatus, PaymentMode
from app.models.cheque import Cheque, ChequeStatus
from app.models.customer import Customer
from app.models.empty_bottle import EmptyBottleTransaction, EmptyBottleTxnType
from app.models.product import Product, ProductVariant
from app.schemas.bill import BillCreate, BillUpdate
from app.utils.audit import write_audit

TWO = Decimal("0.01")


def _fy_prefix(d: date) -> str:
    # Indian FY: Apr-Mar; e.g., 2026-04-20 -> 26-27
    if d.month >= 4:
        start = d.year % 100
        end = (d.year + 1) % 100
    else:
        start = (d.year - 1) % 100
        end = d.year % 100
    return f"{start:02d}-{end:02d}"


def _next_bill_number(db: Session, bill_date: date) -> str:
    fy = _fy_prefix(bill_date)
    prefix = f"{settings.BILL_CODE_DEFAULT}/{fy}/"
    like_pattern = f"{prefix}%"
    max_num = db.scalar(
        select(func.max(Bill.bill_number)).where(Bill.bill_number.like(like_pattern))
    )
    next_seq = 1
    if max_num:
        try:
            next_seq = int(max_num.rsplit("/", 1)[1]) + 1
        except (ValueError, IndexError):
            next_seq = 1
    return f"{prefix}{next_seq:04d}"


def _load_variant_with_product(db: Session, variant_id: int) -> tuple[ProductVariant, Product]:
    v = db.get(ProductVariant, variant_id)
    if not v or not v.is_active:
        raise HTTPException(status_code=400, detail=f"Variant {variant_id} not found or inactive")
    p = db.get(Product, v.product_id)
    return v, p


def create_bill(db: Session, payload: BillCreate, user_id: int) -> Bill:
    customer = db.get(Customer, payload.customer_id)
    if not customer or customer.is_deleted:
        raise HTTPException(status_code=400, detail="Customer not found")

    bill_date = payload.bill_date or date.today()

    subtotal = Decimal("0")
    gst_total = Decimal("0")
    net_cylinders_issued = 0  # +issued - returned across returnable items
    bill_items: list[BillItem] = []

    for item in payload.items:
        variant, product = _load_variant_with_product(db, item.product_variant_id)
        rate = Decimal(item.rate) if item.rate is not None else variant.unit_price
        gst_rate = Decimal(item.gst_rate) if item.gst_rate is not None else variant.gst_rate
        # rate is GST-inclusive: total = rate * qty; derive gst and base from total
        line_total = (rate * item.quantity).quantize(TWO)
        gst_amount = (line_total * gst_rate / (Decimal(100) + gst_rate)).quantize(TWO)
        line_base = (line_total - gst_amount).quantize(TWO)
        subtotal += line_base
        gst_total += gst_amount

        if product.is_returnable:
            net_cylinders_issued += item.quantity - item.empty_returned

        if variant.stock_quantity is not None and variant.stock_quantity > 0:
            variant.stock_quantity = max(0, variant.stock_quantity - item.quantity)

        bill_items.append(BillItem(
            product_variant_id=variant.id,
            quantity=item.quantity,
            rate=rate,
            empty_returned=item.empty_returned,
            gst_rate=gst_rate,
            gst_amount=gst_amount,
            line_total=line_total,
        ))

    discount = Decimal(payload.discount or 0)
    # subtotal + gst_total already equals sum(line_total) — don't double-add
    total_amount = (subtotal + gst_total - discount).quantize(TWO)
    amount_paid = Decimal(payload.amount_paid or 0).quantize(TWO)
    balance_due = (total_amount - amount_paid).quantize(TWO)

    bill = Bill(
        bill_number=_next_bill_number(db, bill_date),
        bill_date=bill_date,
        customer_id=customer.id,
        subtotal=subtotal.quantize(TWO),
        discount=discount.quantize(TWO),
        gst_amount=gst_total.quantize(TWO),
        total_amount=total_amount,
        amount_paid=amount_paid,
        balance_due=balance_due,
        payment_mode=payload.payment_mode,
        cheque_details=payload.cheque_details.model_dump(mode="json") if payload.cheque_details else None,
        notes=payload.notes,
        status=BillStatus.CONFIRMED,
        created_by_id=user_id,
    )
    bill.items = bill_items
    db.add(bill)
    db.flush()

    # update customer balance
    customer.current_balance = (customer.current_balance + balance_due).quantize(TWO)

    # empty bottle tracking
    if net_cylinders_issued != 0:
        customer.current_empty_bottles += net_cylinders_issued
        txn_type = EmptyBottleTxnType.ISSUED if net_cylinders_issued > 0 else EmptyBottleTxnType.RETURNED
        db.add(EmptyBottleTransaction(
            customer_id=customer.id,
            bill_id=bill.id,
            transaction_type=txn_type,
            quantity=net_cylinders_issued,
            balance_after=customer.current_empty_bottles,
            notes=f"Bill {bill.bill_number}",
            created_by_id=user_id,
        ))

    # cheque register
    if payload.payment_mode == PaymentMode.CHEQUE and payload.cheque_details and amount_paid > 0:
        db.add(Cheque(
            cheque_number=payload.cheque_details.cheque_number,
            bank_name=payload.cheque_details.bank_name,
            branch_name=payload.cheque_details.branch_name,
            cheque_date=payload.cheque_details.cheque_date,
            amount=amount_paid,
            customer_id=customer.id,
            bill_id=bill.id,
            status=ChequeStatus.PENDING,
            created_by_id=user_id,
        ))

    write_audit(db, entity_type="bill", entity_id=bill.id,
                action=AuditAction.CREATE, user_id=user_id,
                changes={"bill_number": bill.bill_number, "total": str(total_amount)})
    db.commit()
    db.refresh(bill)
    return bill


def get_bill(db: Session, bill_id: int) -> Bill:
    bill = db.scalar(
        select(Bill).options(selectinload(Bill.items)).where(Bill.id == bill_id)
    )
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")
    return bill


def list_bills(
    db: Session,
    *,
    customer_id: Optional[int] = None,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    status: Optional[BillStatus] = None,
    bill_number_from: Optional[str] = None,
    bill_number_to: Optional[str] = None,
    do_id: Optional[int] = None,
    city: Optional[str] = None,
):
    stmt = select(Bill).order_by(Bill.bill_date.desc(), Bill.id.desc())
    if customer_id:
        stmt = stmt.where(Bill.customer_id == customer_id)
    if from_date:
        stmt = stmt.where(Bill.bill_date >= from_date)
    if to_date:
        stmt = stmt.where(Bill.bill_date <= to_date)
    if status:
        stmt = stmt.where(Bill.status == status)
    if bill_number_from:
        stmt = stmt.where(Bill.bill_number >= bill_number_from)
    if bill_number_to:
        stmt = stmt.where(Bill.bill_number <= bill_number_to)
    if do_id is not None or city:
        stmt = stmt.join(Customer, Bill.customer_id == Customer.id)
        if do_id is not None:
            stmt = stmt.where(Customer.do_id == do_id)
        if city:
            stmt = stmt.where(Customer.city.ilike(f"%{city}%"))
    return stmt


def update_bill(db: Session, bill_id: int, payload: BillUpdate, user_id: int) -> Bill:
    bill = get_bill(db, bill_id)
    if bill.status == BillStatus.CANCELLED:
        raise HTTPException(status_code=400, detail="Cannot edit cancelled bill")

    old_balance = bill.balance_due
    for k, v in payload.model_dump(exclude_unset=True).items():
        if k == "cheque_details" and v is not None:
            # keep as plain dict
            bill.cheque_details = payload.cheque_details.model_dump(mode="json")
        else:
            setattr(bill, k, v)

    # recompute balance if discount or amount_paid changed
    bill.balance_due = (bill.total_amount - Decimal(bill.amount_paid or 0)).quantize(TWO)

    # adjust customer balance by delta
    diff = bill.balance_due - old_balance
    if diff:
        customer = db.get(Customer, bill.customer_id)
        customer.current_balance = (customer.current_balance + diff).quantize(TWO)

    write_audit(db, entity_type="bill", entity_id=bill.id,
                action=AuditAction.UPDATE, user_id=user_id)
    db.commit()
    db.refresh(bill)
    return bill


def cancel_bill(db: Session, bill_id: int, user_id: int) -> Bill:
    bill = get_bill(db, bill_id)
    if bill.status == BillStatus.CANCELLED:
        raise HTTPException(status_code=400, detail="Bill already cancelled")

    customer = db.get(Customer, bill.customer_id)
    # reverse balance
    customer.current_balance = (customer.current_balance - bill.balance_due).quantize(TWO)

    # reverse empty bottle transactions for this bill
    reversals = db.scalars(
        select(EmptyBottleTransaction).where(EmptyBottleTransaction.bill_id == bill.id)
    ).all()
    for tx in reversals:
        customer.current_empty_bottles -= tx.quantity
    if reversals:
        db.add(EmptyBottleTransaction(
            customer_id=customer.id,
            bill_id=bill.id,
            transaction_type=EmptyBottleTxnType.ADJUSTMENT,
            quantity=-sum(tx.quantity for tx in reversals),
            balance_after=customer.current_empty_bottles,
            notes=f"Cancel bill {bill.bill_number}",
            created_by_id=user_id,
        ))

    # restore stock
    for item in bill.items:
        v = db.get(ProductVariant, item.product_variant_id)
        if v:
            v.stock_quantity += item.quantity

    # cancel associated cheque(s)
    for cheque in db.scalars(select(Cheque).where(Cheque.bill_id == bill.id)).all():
        if cheque.status == ChequeStatus.PENDING:
            cheque.status = ChequeStatus.CANCELLED

    bill.status = BillStatus.CANCELLED
    write_audit(db, entity_type="bill", entity_id=bill.id,
                action=AuditAction.CANCEL, user_id=user_id)
    db.commit()
    db.refresh(bill)
    return bill


def customer_ledger(db: Session, customer_id: int):
    from app.models.payment import Payment
    customer = db.get(Customer, customer_id)
    if not customer or customer.is_deleted:
        raise HTTPException(status_code=404, detail="Customer not found")

    entries = []
    running = Decimal(customer.opening_balance or 0)
    entries.append({
        "date": customer.registration_date, "type": "opening",
        "reference": "OPENING", "debit": running, "credit": Decimal("0"),
        "balance": running, "notes": "Opening balance",
    })

    bills = db.scalars(
        select(Bill).where(Bill.customer_id == customer_id, Bill.status != BillStatus.CANCELLED)
        .order_by(Bill.bill_date, Bill.id)
    ).all()
    payments = db.scalars(
        select(Payment).where(Payment.customer_id == customer_id)
        .order_by(Payment.payment_date, Payment.id)
    ).all()

    # merge and order by date
    events = [("bill", b) for b in bills] + [("payment", p) for p in payments]
    events.sort(key=lambda e: (e[1].bill_date if e[0] == "bill" else e[1].payment_date, e[1].id))

    for kind, ev in events:
        if kind == "bill":
            running += ev.balance_due
            entries.append({
                "date": ev.bill_date, "type": "bill", "reference": ev.bill_number,
                "debit": ev.total_amount, "credit": ev.amount_paid,
                "balance": running, "notes": ev.notes,
            })
        else:
            running -= ev.amount
            entries.append({
                "date": ev.payment_date, "type": "payment", "reference": ev.payment_number,
                "debit": Decimal("0"), "credit": ev.amount,
                "balance": running, "notes": ev.notes,
            })

    return {
        "customer_id": customer.id,
        "customer_name": customer.name,
        "mobile": customer.mobile,
        "opening_balance": customer.opening_balance,
        "entries": entries,
        "closing_balance": running,
    }
