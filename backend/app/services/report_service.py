from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.models.bill import Bill, BillItem, BillStatus, PaymentMode
from app.models.customer import Customer
from app.models.payment import Payment, PaymentStatus
from app.models.product import Product, ProductVariant
from app.schemas.report import (
    CashBookReport, CashBookRow, DailySalesReport, DailySalesRow,
    EmptyBottleReport, EmptyBottleRow, GstReport, GstSummaryRow,
    OutstandingReport, OutstandingRow, ProductSalesReport, ProductSalesRow,
)

ZERO = Decimal("0")


def daily_sales(db: Session, from_date: date, to_date: date) -> DailySalesReport:
    mode_sum = lambda m: func.sum(case((Bill.payment_mode == m, Bill.amount_paid), else_=ZERO))
    stmt = (
        select(
            Bill.bill_date,
            func.count(Bill.id).label("bills_count"),
            func.sum(Bill.total_amount).label("total_sales"),
            mode_sum(PaymentMode.CASH).label("cash"),
            mode_sum(PaymentMode.CHEQUE).label("cheque"),
            mode_sum(PaymentMode.UPI).label("upi"),
            mode_sum(PaymentMode.CARD).label("card"),
            func.sum(case((Bill.payment_mode == PaymentMode.CREDIT, Bill.total_amount), else_=ZERO)).label("credit"),
        )
        .where(
            Bill.bill_date.between(from_date, to_date),
            Bill.status != BillStatus.CANCELLED,
        )
        .group_by(Bill.bill_date)
        .order_by(Bill.bill_date)
    )
    rows: list[DailySalesRow] = []
    total_sales = ZERO
    total_collected = ZERO
    for r in db.execute(stmt):
        total_sales += r.total_sales or ZERO
        collected = (r.cash or ZERO) + (r.cheque or ZERO) + (r.upi or ZERO) + (r.card or ZERO)
        total_collected += collected
        rows.append(DailySalesRow(
            date=r.bill_date,
            bills_count=r.bills_count,
            total_sales=r.total_sales or ZERO,
            cash_collected=r.cash or ZERO,
            cheque_collected=r.cheque or ZERO,
            upi_collected=r.upi or ZERO,
            card_collected=r.card or ZERO,
            credit_given=r.credit or ZERO,
        ))
    return DailySalesReport(
        from_date=from_date, to_date=to_date, rows=rows,
        grand_total_sales=total_sales, grand_total_collected=total_collected,
    )


def outstanding(db: Session) -> OutstandingReport:
    stmt = (
        select(Customer)
        .where(Customer.is_deleted.is_(False), Customer.current_balance > 0)
        .order_by(Customer.current_balance.desc())
    )
    customers = db.scalars(stmt).all()
    rows = [OutstandingRow(
        customer_id=c.id, customer_name=c.name, mobile=c.mobile, village=c.village,
        current_balance=c.current_balance, current_empty_bottles=c.current_empty_bottles,
    ) for c in customers]
    return OutstandingReport(
        total_customers=len(rows),
        total_outstanding=sum((c.current_balance for c in customers), ZERO),
        rows=rows,
    )


def empty_bottles(db: Session) -> EmptyBottleReport:
    stmt = (
        select(Customer)
        .where(Customer.is_deleted.is_(False), Customer.current_empty_bottles > 0)
        .order_by(Customer.current_empty_bottles.desc())
    )
    customers = db.scalars(stmt).all()
    rows = [EmptyBottleRow(
        customer_id=c.id, customer_name=c.name, mobile=c.mobile, village=c.village,
        empty_bottles=c.current_empty_bottles,
    ) for c in customers]
    return EmptyBottleReport(
        total_empty=sum(c.current_empty_bottles for c in customers),
        rows=rows,
    )


def product_wise_sales(db: Session, from_date: date, to_date: date) -> ProductSalesReport:
    stmt = (
        select(
            BillItem.product_variant_id,
            ProductVariant.name.label("variant_name"),
            Product.name.label("product_name"),
            func.sum(BillItem.quantity).label("qty"),
            func.sum(BillItem.line_total).label("amount"),
        )
        .join(ProductVariant, ProductVariant.id == BillItem.product_variant_id)
        .join(Product, Product.id == ProductVariant.product_id)
        .join(Bill, Bill.id == BillItem.bill_id)
        .where(
            Bill.bill_date.between(from_date, to_date),
            Bill.status != BillStatus.CANCELLED,
        )
        .group_by(BillItem.product_variant_id, ProductVariant.name, Product.name)
        .order_by(func.sum(BillItem.line_total).desc())
    )
    rows = [ProductSalesRow(
        variant_id=r.product_variant_id, variant_name=r.variant_name,
        product_name=r.product_name, qty_sold=int(r.qty or 0),
        total_amount=r.amount or ZERO,
    ) for r in db.execute(stmt)]
    return ProductSalesReport(from_date=from_date, to_date=to_date, rows=rows)


def cash_book(db: Session, from_date: date, to_date: date) -> CashBookReport:
    # cash IN: bills (cash) + payments (cash, cleared)
    bills_cash = (
        select(Bill.bill_date.label("d"), func.sum(Bill.amount_paid).label("amt"))
        .where(
            Bill.bill_date.between(from_date, to_date),
            Bill.status != BillStatus.CANCELLED,
            Bill.payment_mode == PaymentMode.CASH,
        )
        .group_by(Bill.bill_date)
    ).subquery()

    pay_cash = (
        select(Payment.payment_date.label("d"), func.sum(Payment.amount).label("amt"))
        .where(
            Payment.payment_date.between(from_date, to_date),
            Payment.payment_mode == PaymentMode.CASH,
            Payment.status == PaymentStatus.CLEARED,
            Payment.reference_bill_id.is_(None),  # avoid double-count of on-bill payments
        )
        .group_by(Payment.payment_date)
    ).subquery()

    cur = from_date
    rows: list[CashBookRow] = []
    total_in = ZERO
    # build a date-indexed map
    bill_map = {r.d: r.amt or ZERO for r in db.execute(select(bills_cash))}
    pay_map = {r.d: r.amt or ZERO for r in db.execute(select(pay_cash))}
    while cur <= to_date:
        amt_in = (bill_map.get(cur, ZERO) or ZERO) + (pay_map.get(cur, ZERO) or ZERO)
        rows.append(CashBookRow(date=cur, cash_in=amt_in, cash_out=ZERO, net=amt_in))
        total_in += amt_in
        cur += timedelta(days=1)

    return CashBookReport(
        from_date=from_date, to_date=to_date, rows=rows,
        total_in=total_in, total_out=ZERO, net=total_in,
    )


def gst_summary(db: Session, from_date: date, to_date: date) -> GstReport:
    stmt = (
        select(
            BillItem.gst_rate,
            func.sum(BillItem.rate * BillItem.quantity).label("taxable"),
            func.sum(BillItem.gst_amount).label("gst"),
            func.sum(BillItem.line_total).label("total"),
        )
        .join(Bill, Bill.id == BillItem.bill_id)
        .where(
            Bill.bill_date.between(from_date, to_date),
            Bill.status != BillStatus.CANCELLED,
        )
        .group_by(BillItem.gst_rate)
        .order_by(BillItem.gst_rate)
    )
    rows = []
    total_taxable = ZERO
    total_gst = ZERO
    for r in db.execute(stmt):
        rows.append(GstSummaryRow(
            gst_rate=r.gst_rate, taxable_amount=r.taxable or ZERO,
            gst_amount=r.gst or ZERO, total_amount=r.total or ZERO,
        ))
        total_taxable += r.taxable or ZERO
        total_gst += r.gst or ZERO
    return GstReport(
        from_date=from_date, to_date=to_date, rows=rows,
        total_taxable=total_taxable, total_gst=total_gst,
    )


def dashboard(db: Session) -> dict:
    today = date.today()
    today_bills = db.execute(
        select(
            func.count(Bill.id),
            func.coalesce(func.sum(Bill.total_amount), 0),
            func.coalesce(func.sum(case((Bill.payment_mode == PaymentMode.CASH, Bill.amount_paid), else_=0)), 0),
        ).where(Bill.bill_date == today, Bill.status != BillStatus.CANCELLED)
    ).one()
    today_cylinders = db.scalar(
        select(func.coalesce(func.sum(BillItem.quantity), 0))
        .join(Bill, Bill.id == BillItem.bill_id)
        .join(ProductVariant, ProductVariant.id == BillItem.product_variant_id)
        .join(Product, Product.id == ProductVariant.product_id)
        .where(
            Bill.bill_date == today,
            Bill.status != BillStatus.CANCELLED,
            Product.is_returnable.is_(True),
        )
    ) or 0
    outstanding_total = db.scalar(
        select(func.coalesce(func.sum(Customer.current_balance), 0))
        .where(Customer.is_deleted.is_(False), Customer.current_balance > 0)
    ) or 0
    pending_empty = db.scalar(
        select(func.coalesce(func.sum(Customer.current_empty_bottles), 0))
        .where(Customer.is_deleted.is_(False), Customer.current_empty_bottles > 0)
    ) or 0

    return {
        "today_bills_count": today_bills[0] or 0,
        "today_sales_total": today_bills[1] or 0,
        "today_cash_collected": today_bills[2] or 0,
        "today_cylinders_sold": int(today_cylinders),
        "total_outstanding": outstanding_total,
        "total_pending_empty": int(pending_empty),
    }
