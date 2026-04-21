from decimal import Decimal
from io import BytesIO
from typing import Iterable

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.bill import Bill
from app.models.customer import Customer
from app.models.product import Product, ProductVariant
from app.models.setting import Setting


def _business_header(db: Session) -> dict:
    keys = ["business_name", "business_address", "business_mobile", "business_gstin", "bill_tagline"]
    rows = db.scalars(select(Setting).where(Setting.key.in_(keys))).all()
    m = {r.key: r.value for r in rows}
    return {
        "name": m.get("business_name", "Gas Cylinder Distribution"),
        "address": m.get("business_address", ""),
        "mobile": m.get("business_mobile", ""),
        "gstin": m.get("business_gstin", ""),
        "tagline": m.get("bill_tagline", ""),
    }


def _variant_label(db: Session, variant_id: int) -> str:
    v = db.get(ProductVariant, variant_id)
    if not v:
        return f"Variant #{variant_id}"
    p = db.get(Product, v.product_id)
    return f"{p.name if p else ''} - {v.name}".strip(" -")


def render_bill_pdf(db: Session, bill: Bill) -> bytes:
    customer = db.get(Customer, bill.customer_id)
    business = _business_header(db)

    buf = BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm,
                            topMargin=15 * mm, bottomMargin=15 * mm)
    styles = getSampleStyleSheet()
    title = ParagraphStyle("Title", parent=styles["Title"], alignment=1, fontSize=16)
    normal = styles["Normal"]
    small = ParagraphStyle("Small", parent=styles["Normal"], fontSize=9)

    flow = []
    flow.append(Paragraph(f"<b>{business['name']}</b>", title))
    if business["address"]:
        flow.append(Paragraph(business["address"], ParagraphStyle("c", parent=normal, alignment=1)))
    if business["mobile"] or business["gstin"]:
        flow.append(Paragraph(
            f"Mobile: {business['mobile']} &nbsp;&nbsp; GSTIN: {business['gstin']}",
            ParagraphStyle("c2", parent=normal, alignment=1, fontSize=9),
        ))
    flow.append(Spacer(1, 6 * mm))

    flow.append(Paragraph(f"<b>BILL</b>  #{bill.bill_number}", normal))
    flow.append(Paragraph(f"Date: {bill.bill_date.strftime('%d-%m-%Y')}", normal))
    flow.append(Spacer(1, 3 * mm))

    if customer:
        flow.append(Paragraph(
            f"<b>Customer:</b> {customer.name} — {customer.village}<br/>"
            f"Mobile: {customer.mobile}<br/>"
            f"{customer.full_address or ''}",
            normal,
        ))
    flow.append(Spacer(1, 4 * mm))

    table_data = [["#", "Item", "Qty", "Rate", "GST %", "Empty Ret.", "Total"]]
    for i, item in enumerate(bill.items, start=1):
        table_data.append([
            i, _variant_label(db, item.product_variant_id),
            item.quantity, f"{item.rate:.2f}", f"{item.gst_rate:.2f}",
            item.empty_returned, f"{item.line_total:.2f}",
        ])
    t = Table(table_data, colWidths=[10 * mm, 70 * mm, 15 * mm, 20 * mm, 15 * mm, 20 * mm, 25 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.lightgrey),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("GRID", (0, 0), (-1, -1), 0.25, colors.grey),
        ("ALIGN", (2, 1), (-1, -1), "RIGHT"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
    ]))
    flow.append(t)
    flow.append(Spacer(1, 5 * mm))

    totals = [
        ["Subtotal", f"{bill.subtotal:.2f}"],
        ["GST", f"{bill.gst_amount:.2f}"],
        ["Discount", f"{bill.discount:.2f}"],
        ["Total", f"{bill.total_amount:.2f}"],
        ["Paid", f"{bill.amount_paid:.2f}"],
        ["Balance Due", f"{bill.balance_due:.2f}"],
    ]
    tt = Table(totals, colWidths=[40 * mm, 40 * mm], hAlign="RIGHT")
    tt.setStyle(TableStyle([
        ("GRID", (0, 0), (-1, -1), 0.25, colors.grey),
        ("ALIGN", (1, 0), (1, -1), "RIGHT"),
        ("FONTNAME", (0, 3), (1, 3), "Helvetica-Bold"),
        ("FONTNAME", (0, 5), (1, 5), "Helvetica-Bold"),
    ]))
    flow.append(tt)

    if bill.notes:
        flow.append(Spacer(1, 5 * mm))
        flow.append(Paragraph(f"<b>Notes:</b> {bill.notes}", small))

    if business["tagline"]:
        flow.append(Spacer(1, 6 * mm))
        flow.append(Paragraph(business["tagline"], ParagraphStyle("tag", parent=small, alignment=1)))

    doc.build(flow)
    return buf.getvalue()


# -------- 9-up bills per A4 (3 cols x 3 rows) --------
PAGE_W, PAGE_H = A4
MARGIN = 8 * mm
COLS = 3
ROWS = 3


def render_bills_9up_pdf(db: Session, bills: Iterable[Bill]) -> bytes:
    buf = BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    business = _business_header(db)

    cell_w = (PAGE_W - 2 * MARGIN) / COLS
    cell_h = (PAGE_H - 2 * MARGIN) / ROWS

    bills = list(bills)
    if not bills:
        c.setFont("Helvetica", 12)
        c.drawString(MARGIN, PAGE_H - MARGIN - 10, "No bills in the selected range.")
        c.save()
        return buf.getvalue()

    for index, bill in enumerate(bills):
        pos = index % (COLS * ROWS)
        if pos == 0 and index > 0:
            c.showPage()
        col = pos % COLS
        row = pos // COLS
        x = MARGIN + col * cell_w
        y = PAGE_H - MARGIN - (row + 1) * cell_h
        _draw_mini_bill(c, db, bill, x, y, cell_w, cell_h, business)

    c.save()
    return buf.getvalue()


def _draw_mini_bill(c, db: Session, bill: Bill, x: float, y: float, w: float, h: float, business: dict):
    pad = 3 * mm
    c.setStrokeColor(colors.grey)
    c.rect(x, y, w, h)

    ty = y + h - pad
    c.setFont("Helvetica-Bold", 9)
    c.drawString(x + pad, ty, business["name"][:40])
    ty -= 4 * mm
    c.setFont("Helvetica", 7)
    if business["mobile"]:
        c.drawString(x + pad, ty, f"Ph: {business['mobile']}")
        ty -= 3 * mm

    # bill header row
    c.setFont("Helvetica-Bold", 8)
    c.drawString(x + pad, ty, f"Bill: {bill.bill_number}")
    c.drawRightString(x + w - pad, ty, bill.bill_date.strftime("%d-%m-%Y"))
    ty -= 4 * mm

    # customer
    customer = db.get(Customer, bill.customer_id)
    c.setFont("Helvetica", 8)
    if customer:
        c.drawString(x + pad, ty, f"{customer.name[:28]} — {customer.village[:14]}")
        ty -= 3 * mm
        c.setFont("Helvetica", 7)
        c.drawString(x + pad, ty, f"Mob: {customer.mobile}")
        ty -= 3 * mm

    # items (max 5)
    c.setFont("Helvetica-Bold", 7)
    c.drawString(x + pad, ty, "Item")
    c.drawRightString(x + w - pad - 22 * mm, ty, "Qty")
    c.drawRightString(x + w - pad, ty, "Amt")
    ty -= 3 * mm
    c.setFont("Helvetica", 7)
    for item in bill.items[:5]:
        name = _variant_label(db, item.product_variant_id)[:32]
        c.drawString(x + pad, ty, name)
        c.drawRightString(x + w - pad - 22 * mm, ty, str(item.quantity))
        c.drawRightString(x + w - pad, ty, f"{item.line_total:.0f}")
        ty -= 3 * mm
    if len(bill.items) > 5:
        c.drawString(x + pad, ty, f"...+{len(bill.items) - 5} more items")
        ty -= 3 * mm

    # totals
    ty -= 1 * mm
    c.setStrokeColor(colors.lightgrey)
    c.line(x + pad, ty, x + w - pad, ty)
    ty -= 3 * mm
    c.setFont("Helvetica-Bold", 7)
    c.drawString(x + pad, ty, "Total")
    c.drawRightString(x + w - pad, ty, f"{bill.total_amount:.2f}")
    ty -= 3 * mm
    c.setFont("Helvetica", 7)
    c.drawString(x + pad, ty, "Paid")
    c.drawRightString(x + w - pad, ty, f"{bill.amount_paid:.2f}")
    ty -= 3 * mm
    c.setFont("Helvetica-Bold", 7)
    c.drawString(x + pad, ty, "Balance")
    c.drawRightString(x + w - pad, ty, f"{bill.balance_due:.2f}")
