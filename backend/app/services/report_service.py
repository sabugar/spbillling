from datetime import date, datetime, timedelta
from decimal import Decimal
from io import BytesIO

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle,
)
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


# ===========================================================================
# Registers — daily and DO-wise rollups for the sidebar "Register" pages.
# ===========================================================================

def _short_serial(bill_no: str | None) -> str:
    """`BILL/26-27/0017` -> `0017`. Anything else returned unchanged."""
    if not bill_no:
        return ""
    return bill_no.rsplit("/", 1)[-1]


def daily_register(
    db: Session,
    from_date: date,
    to_date: date,
    *,
    do_id: int | None = None,
) -> list[dict]:
    """One row per day with the bill# range, count, and total amount."""
    stmt = (
        select(
            Bill.bill_date.label("bill_date"),
            func.min(Bill.bill_number).label("bill_from"),
            func.max(Bill.bill_number).label("bill_to"),
            func.count(Bill.id).label("qty"),
            func.coalesce(func.sum(Bill.total_amount), 0).label("total"),
        )
        .where(
            Bill.bill_date >= from_date,
            Bill.bill_date <= to_date,
            Bill.status == BillStatus.CONFIRMED,
        )
        .group_by(Bill.bill_date)
        .order_by(Bill.bill_date.asc())
    )
    if do_id:
        stmt = stmt.join(Customer, Bill.customer_id == Customer.id).where(
            Customer.do_id == do_id
        )
    rows = db.execute(stmt).all()
    return [
        {
            "date": r.bill_date.isoformat(),
            "bill_from": _short_serial(r.bill_from),
            "bill_to": _short_serial(r.bill_to),
            "qty": int(r.qty),
            "total": str(r.total),
        }
        for r in rows
    ]


def do_register(
    db: Session,
    from_date: date,
    to_date: date,
    *,
    do_id: int | None = None,
) -> list[dict]:
    """One row per (DO, day): includes do_code, do_name + the daily numbers.
    Pass `do_id` to scope the report to a single Distributor Outlet."""
    from app.models.distributor_outlet import DistributorOutlet
    stmt = (
        select(
            DistributorOutlet.id.label("do_id"),
            DistributorOutlet.code.label("do_code"),
            DistributorOutlet.owner_name.label("do_name"),
            DistributorOutlet.location.label("do_location"),
            Bill.bill_date.label("bill_date"),
            func.min(Bill.bill_number).label("bill_from"),
            func.max(Bill.bill_number).label("bill_to"),
            func.count(Bill.id).label("qty"),
            func.coalesce(func.sum(Bill.total_amount), 0).label("total"),
        )
        .join(Customer, Bill.customer_id == Customer.id)
        .join(DistributorOutlet, Customer.do_id == DistributorOutlet.id)
        .where(
            Bill.bill_date >= from_date,
            Bill.bill_date <= to_date,
            Bill.status == BillStatus.CONFIRMED,
        )
        .group_by(
            DistributorOutlet.id,
            DistributorOutlet.code,
            DistributorOutlet.owner_name,
            DistributorOutlet.location,
            Bill.bill_date,
        )
        .order_by(
            DistributorOutlet.code.asc(), Bill.bill_date.asc()
        )
    )
    if do_id:
        stmt = stmt.where(DistributorOutlet.id == do_id)
    rows = db.execute(stmt).all()
    return [
        {
            "do_id": r.do_id,
            "do_code": r.do_code,
            "do_name": r.do_name,
            "do_location": r.do_location,
            "date": r.bill_date.isoformat(),
            "bill_from": _short_serial(r.bill_from),
            "bill_to": _short_serial(r.bill_to),
            "qty": int(r.qty),
            "total": str(r.total),
        }
        for r in rows
    ]


# ---------- Register exports (Excel + PDF) ----------

_HEADER_FILL = PatternFill("solid", fgColor="0F766E")
_HEADER_FONT = Font(bold=True, color="FFFFFF")


def _fmt_date_str(iso: str) -> str:
    try:
        return datetime.fromisoformat(iso).strftime("%d %b %Y")
    except Exception:
        return iso


def _autofit(ws) -> None:
    from openpyxl.utils import get_column_letter
    for col_idx in range(1, ws.max_column + 1):
        widest = 8
        for row_idx in range(1, ws.max_row + 1):
            cell = ws.cell(row=row_idx, column=col_idx)
            # Skip merged-cell stand-ins (MergedCell rows have no real value).
            v = cell.value
            if v is None:
                continue
            widest = max(widest, len(str(v)))
        ws.column_dimensions[get_column_letter(col_idx)].width = min(40, widest + 4)


def daily_register_excel(
    db: Session,
    from_date: date,
    to_date: date,
    *,
    do_id: int | None = None,
) -> bytes:
    rows = daily_register(db, from_date, to_date, do_id=do_id)
    wb = Workbook()
    ws = wb.active
    ws.title = "Daily Register"
    ws.append([f"Daily Register · {from_date.strftime('%d %b %Y')} → {to_date.strftime('%d %b %Y')}"])
    ws.merge_cells(start_row=1, end_row=1, start_column=1, end_column=5)
    ws["A1"].font = Font(bold=True, size=14)
    ws["A1"].alignment = Alignment(horizontal="center")
    headers = ["Date", "Bill # From", "Bill # To", "Qty", "Total (Rs.)"]
    ws.append([])
    ws.append(headers)
    for cell in ws[3]:
        cell.fill = _HEADER_FILL
        cell.font = _HEADER_FONT
        cell.alignment = Alignment(horizontal="center")
    total_qty = 0
    total_amt = Decimal("0")
    for r in rows:
        ws.append([
            _fmt_date_str(r["date"]),
            r["bill_from"], r["bill_to"], r["qty"], float(r["total"]),
        ])
        total_qty += r["qty"]
        total_amt += Decimal(r["total"])
    ws.append([])
    ws.append(["TOTAL", "", "", total_qty, float(total_amt)])
    last = ws.max_row
    for cell in ws[last]:
        cell.font = Font(bold=True)
    _autofit(ws)
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _table_pdf(title: str, headers: list[str], data: list[list],
               totals: list | None = None) -> bytes:
    buf = BytesIO()
    doc = SimpleDocTemplate(
        buf, pagesize=A4,
        leftMargin=12 * mm, rightMargin=12 * mm,
        topMargin=12 * mm, bottomMargin=12 * mm,
    )
    styles = getSampleStyleSheet()
    story = [Paragraph(f"<b>{title}</b>", styles["Title"]), Spacer(1, 6)]
    body = [headers] + data
    if totals:
        body.append(totals)
    tbl = Table(body, repeatRows=1)
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0F766E")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("ALIGN", (0, 0), (-1, 0), "CENTER"),
        ("ALIGN", (-2, 1), (-1, -1), "RIGHT"),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#E4E7EE")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -2 if totals else -1),
         [colors.white, colors.HexColor("#F7F8FB")]),
        ("BACKGROUND", (0, -1), (-1, -1),
         colors.HexColor("#F1F3F8") if totals else colors.white),
        ("FONTNAME", (0, -1), (-1, -1),
         "Helvetica-Bold" if totals else "Helvetica"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    story.append(tbl)
    doc.build(story)
    return buf.getvalue()


def daily_register_pdf(
    db: Session,
    from_date: date,
    to_date: date,
    *,
    do_id: int | None = None,
) -> bytes:
    rows = daily_register(db, from_date, to_date, do_id=do_id)
    title = (
        f"Daily Register · {from_date.strftime('%d %b %Y')} → "
        f"{to_date.strftime('%d %b %Y')}"
    )
    data = [
        [_fmt_date_str(r["date"]), r["bill_from"], r["bill_to"],
         str(r["qty"]), f"Rs. {Decimal(r['total']):,.2f}"]
        for r in rows
    ]
    total_qty = sum(r["qty"] for r in rows)
    total_amt = sum(Decimal(r["total"]) for r in rows) if rows else Decimal("0")
    totals = ["TOTAL", "", "", str(total_qty), f"Rs. {total_amt:,.2f}"]
    return _table_pdf(
        title, ["Date", "Bill # From", "Bill # To", "Qty", "Total"],
        data, totals,
    )


def do_register_excel(
    db: Session,
    from_date: date,
    to_date: date,
    *,
    do_id: int | None = None,
) -> bytes:
    rows = do_register(db, from_date, to_date, do_id=do_id)
    # Exports must read date-first ascending — DO code is secondary tie-break.
    rows.sort(key=lambda r: (r["date"], r["do_code"]))
    wb = Workbook()
    ws = wb.active
    ws.title = "DO Register"
    title = "DO Register"
    if do_id and rows:
        title += f" · {rows[0]['do_code']} / {rows[0]['do_name']}"
    title += (
        f" · {from_date.strftime('%d %b %Y')} → {to_date.strftime('%d %b %Y')}"
    )
    ws.append([title])
    ws.merge_cells(start_row=1, end_row=1, start_column=1, end_column=7)
    ws["A1"].font = Font(bold=True, size=14)
    ws["A1"].alignment = Alignment(horizontal="center")
    headers = ["DO Code", "DO Name", "Location", "Date",
               "Bill # From", "Bill # To", "Qty", "Total (Rs.)"]
    ws.append([])
    ws.append(headers)
    for cell in ws[3]:
        cell.fill = _HEADER_FILL
        cell.font = _HEADER_FONT
        cell.alignment = Alignment(horizontal="center")
    total_qty = 0
    total_amt = Decimal("0")
    for r in rows:
        ws.append([
            r["do_code"], r["do_name"], r.get("do_location") or "",
            _fmt_date_str(r["date"]),
            r["bill_from"], r["bill_to"],
            r["qty"], float(r["total"]),
        ])
        total_qty += r["qty"]
        total_amt += Decimal(r["total"])
    ws.append([])
    ws.append(["TOTAL", "", "", "", "", "", total_qty, float(total_amt)])
    for cell in ws[ws.max_row]:
        cell.font = Font(bold=True)
    _autofit(ws)
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue()


def do_register_pdf(
    db: Session,
    from_date: date,
    to_date: date,
    *,
    do_id: int | None = None,
) -> bytes:
    rows = do_register(db, from_date, to_date, do_id=do_id)
    rows.sort(key=lambda r: (r["date"], r["do_code"]))
    title = "DO Register"
    if do_id and rows:
        title += f" — {rows[0]['do_code']} / {rows[0]['do_name']}"
    title += (
        f" · {from_date.strftime('%d %b %Y')} to {to_date.strftime('%d %b %Y')}"
    )
    headers = ["DO", "Date", "Bill # From", "Bill # To", "Qty", "Total"]
    data = [
        [f"{r['do_code']} · {r['do_name']}", _fmt_date_str(r["date"]),
         r["bill_from"], r["bill_to"], str(r["qty"]),
         f"Rs. {Decimal(r['total']):,.2f}"]
        for r in rows
    ]
    total_qty = sum(r["qty"] for r in rows)
    total_amt = sum(Decimal(r["total"]) for r in rows) if rows else Decimal("0")
    totals = ["TOTAL", "", "", "", str(total_qty), f"Rs. {total_amt:,.2f}"]
    return _table_pdf(title, headers, data, totals)
