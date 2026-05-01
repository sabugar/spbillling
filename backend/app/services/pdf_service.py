import os
from decimal import Decimal
from io import BytesIO
from typing import Iterable, Optional

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


# =============================================================================
# SP Gas Agency full bill template — replicates the printed stationery
# entirely (logo, header, address bar, all labels + boxes + GST IN footer)
# AND fills in the per-bill data. Used for both single-bill PDF and 6-up
# batch PDF. Logical bill is 95×92mm at scale=1; pass scale=2 for full A4
# single bill.
# =============================================================================


def _split_rs_ps(amount: Decimal) -> tuple[str, str]:
    """Split a decimal amount into (rupees_str, paisa_str_2digits)."""
    q = amount.quantize(Decimal("0.01"))
    rs = int(q)
    ps = int((q - rs) * 100)
    return str(rs), f"{ps:02d}"


_ASSETS_DIR = os.path.join(os.path.dirname(__file__), "assets")
_LOGO_PATH = os.path.join(_ASSETS_DIR, "reliance_gas_logo.png")
_SIGN_PATH = os.path.join(_ASSETS_DIR, "signature.png")


def _short_bill_no(num: str) -> str:
    """Strip the 'BILL/26-27/' prefix — keep only the trailing serial."""
    return num.rsplit("/", 1)[-1] if num and "/" in num else (num or "")


def _do_name_code(customer: Optional[Customer]) -> str:
    """Build the DO Name & Code string from the customer's distributor outlet.
    Format: 'OwnerName / CODE' (e.g., 'SP Gas / ZM')."""
    if not customer:
        return ""
    do = getattr(customer, "distributor_outlet", None)
    if not do:
        return ""
    if do.owner_name and do.code:
        return f"{do.owner_name} / {do.code}"
    return do.owner_name or do.code or ""


def _customer_address(customer: Optional[Customer]) -> str:
    if not customer:
        return ""
    if customer.full_address:
        return customer.full_address
    parts = [p for p in (customer.village, customer.city) if p]
    return ", ".join(parts)


def _draw_sp_bill_template(c: canvas.Canvas, bill: Bill,
                           bx_mm: float, by_mm: float, scale: float = 1.0) -> None:
    """Draw one complete SP Gas Agency bill (template + data) at (bx, by) mm.

    Logical bill is 95×92mm; pass scale=2 for ~190×184mm (full A4 single).
    """
    customer = bill.customer

    def to_pdf(lx: float, ly: float) -> tuple[float, float]:
        abs_x_mm = bx_mm + lx * scale
        abs_y_top_mm = by_mm + ly * scale
        return abs_x_mm * mm, (297 - abs_y_top_mm) * mm

    def text(lx: float, ly: float, s: str,
             font: str = "Helvetica", size: float = 8.0,
             color: tuple = (0, 0, 0), align: str = "left") -> None:
        c.setFont(font, size * scale)
        c.setFillColorRGB(*color)
        x, y = to_pdf(lx, ly)
        if align == "right":
            c.drawRightString(x, y, s)
        elif align == "center":
            c.drawCentredString(x, y, s)
        else:
            c.drawString(x, y, s)

    def rect_box(lx1: float, ly1: float, lx2: float, ly2: float,
                 stroke: int = 1, fill: int = 0,
                 fill_rgb: Optional[tuple] = None,
                 stroke_rgb: tuple = (0, 0, 0), line_w: float = 0.4) -> None:
        if fill_rgb:
            c.setFillColorRGB(*fill_rgb)
        c.setStrokeColorRGB(*stroke_rgb)
        c.setLineWidth(line_w * scale)
        x1, y1 = to_pdf(lx1, ly1)
        x2, y2 = to_pdf(lx2, ly2)
        c.rect(x1, y2, x2 - x1, y1 - y2, stroke=stroke, fill=fill)

    def hline(lx1: float, ly: float, lx2: float, line_w: float = 0.3) -> None:
        c.setStrokeColorRGB(0, 0, 0)
        c.setLineWidth(line_w * scale)
        x1, y1 = to_pdf(lx1, ly)
        x2, y2 = to_pdf(lx2, ly)
        c.line(x1, y1, x2, y2)

    def img(local_path: str, lx1: float, ly1: float, lx2: float, ly2: float) -> None:
        if not os.path.exists(local_path):
            return
        x1, y1 = to_pdf(lx1, ly1)
        x2, y2 = to_pdf(lx2, ly2)
        c.drawImage(local_path, x1, y2, x2 - x1, y1 - y2,
                    preserveAspectRatio=True, anchor="c", mask="auto")

    # ---------- Outer border ----------
    rect_box(0, 0, 95, 92, line_w=0.6)

    # ---------- Header (Y 0–19) ----------
    # Reliance Gas logo (real image)
    img(_LOGO_PATH, 1, 1, 18, 18.5)

    # Tax Invoice tag (top-right, plain text — no black bg)
    text(94, 3, "Tax Invoice", font="Helvetica", size=7, align="right")

    # Agency name + subtitle (centered between logo and right edge)
    text(56, 9, "S. P. GAS AGENCY", font="Helvetica-Bold", size=13, align="center")
    text(56, 14.5, "AUTHORISED DISTRIBUTORS", font="Helvetica-Bold", size=7,
         align="center")

    # ---------- Address bar (Y 19–25) — plain text, no black bg ----------
    hline(0, 19, 95, line_w=0.4)
    text(2, 23, "Nr. Hathmati Bridge, Idar Highway Road, Himatnagar-383 001.",
         font="Helvetica-Bold", size=7)
    hline(0, 25, 95, line_w=0.4)

    # ---------- DO Name & Code (Y 25–37) ----------
    text(1.5, 30, "DO Name", font="Helvetica", size=7)
    text(1.5, 33.5, "& Code", font="Helvetica", size=7)
    text(20, 32.5, _do_name_code(customer), font="Helvetica-Bold", size=8)
    hline(0, 37, 95)

    # ---------- Bill No / Date (Y 37–46) ----------
    text(1.5, 42, "Bill No. :", font="Helvetica", size=7)
    text(15, 42, _short_bill_no(bill.bill_number), font="Helvetica-Bold", size=8)
    text(50, 42, "Date :", font="Helvetica", size=7)
    text(60, 42, bill.bill_date.strftime("%d-%m-%Y"), font="Helvetica", size=8)

    # ---------- Consumer Name (Y 46–54) ----------
    text(1.5, 51, "Consumer Name :", font="Helvetica", size=7)
    text(28, 51, (customer.name if customer else "")[:30],
         font="Helvetica", size=8)

    # ---------- Consumer number (no label) / Phone (Y 54–62) ----------
    text(1.5, 59, (customer.consumer_number if customer else "") or "",
         font="Helvetica-Bold", size=9)
    text(50, 59, "Phone :", font="Helvetica", size=7)
    text(62, 59, (customer.mobile if customer else "") or "",
         font="Helvetica", size=8)
    hline(0, 62, 95)

    # ---------- PARTICULARS bar (Y 62–67) ----------
    rect_box(0, 62, 95, 67, stroke=0, fill=1, fill_rgb=(0.93, 0.93, 0.93))
    text(2, 65.5, "PARTICULARS", font="Helvetica-Bold", size=8)
    text(89, 65.5, "Rs.", font="Helvetica-Bold", size=7, align="right")
    hline(0, 67, 95)

    # ---------- Cost of Gas + HSN combined box (Y 67–80) ----------
    text(1.5, 72, "Cost of Gas 15kg. (Nos. - 1) (SEAL PACK)",
         font="Helvetica", size=7)
    total_amount = (bill.total_amount or Decimal("0")).quantize(Decimal("0.01"))
    text(89, 72, f"{total_amount:.2f}",
         font="Helvetica-Bold", size=11, align="right")
    text(1.5, 79, "HSN Code - 2711 19 10", font="Helvetica-Bold", size=6)
    hline(0, 80, 95)

    # ---------- GST breakdown (Y 80–86): amount + SGST + CGST ----------
    half = ((bill.gst_amount or Decimal("0")) / Decimal("2")).quantize(Decimal("0.01"))
    sgst_rs, sgst_ps = _split_rs_ps(half)
    cgst_rs, cgst_ps = sgst_rs, sgst_ps
    base_rs, base_ps = _split_rs_ps(bill.subtotal or Decimal("0"))
    gst_text = (
        f"Rs. {base_rs}.{base_ps}"
        f"  +  SGST(5%) {sgst_rs}.{sgst_ps}"
        f"  +  CGST(5%) {cgst_rs}.{cgst_ps}"
        f"  =  {total_amount:.2f}"
    )
    text(2, 84, gst_text, font="Helvetica-Bold", size=8)
    hline(0, 86, 95)

    # ---------- Footer (Y 86–92) — GST IN left, signature stack on right ----------
    text(1.5, 91, "GST IN : 24AAUFS0029D1ZD", font="Helvetica-Bold", size=7)
    # Right-side stack with padding above/below the texts:
    # Y 87.0 "For, S. P. GasAgency" → Y 87.5–90.5 sign (right of GST IN)
    # → Y 91.5 "Auth. Sign"
    text(94, 87.2, "For, S. P. GasAgency", font="Helvetica-Bold", size=6, align="right")
    img(_SIGN_PATH, 73, 87.6, 92, 90.6)
    text(94, 91.5, "Auth. Sign", font="Helvetica-Bold", size=6, align="right")


def render_bills_preprinted_overlay_pdf(db: Session, bills: Iterable[Bill]) -> bytes:
    """Render 6 SP Gas Agency bills per A4 page (2 cols × 3 rows).

    Each bill is fully drawn — logo, header, dark address bar, all labels
    and boxes — exactly like the pre-printed stationery, with bill data
    filled into the appropriate boxes.
    """
    buf = BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)

    bills = list(bills)
    if not bills:
        c.setFont("Helvetica", 12)
        c.drawString(MARGIN, PAGE_H - MARGIN - 10, "No bills in the selected range.")
        c.save()
        return buf.getvalue()

    # Grid: 2 cols × 3 rows on A4 (210×297mm). Each slot ~95×92mm.
    page_margin_x = 8.0   # mm
    page_margin_y = 8.0   # mm
    col_gap = 4.0
    row_gap = 5.0
    row_tops = [
        page_margin_y,
        page_margin_y + 92 + row_gap,
        page_margin_y + 2 * (92 + row_gap),
    ]
    col_lefts = [page_margin_x, page_margin_x + 95 + col_gap]

    for index, bill in enumerate(bills):
        pos = index % 6
        if pos == 0 and index > 0:
            c.showPage()
        col = pos % 2
        row = pos // 2
        _draw_sp_bill_template(c, bill, col_lefts[col], row_tops[row], scale=1.0)

    c.save()
    return buf.getvalue()


def render_bill_sp_single_pdf(bill: Bill) -> bytes:
    """Render a single SP Gas Agency bill on a full A4 page (scaled-up template)."""
    buf = BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)

    # scale=2 → 190×184mm bill. Center on A4 (210×297).
    scale = 2.0
    bill_w = 95 * scale
    bill_h = 92 * scale
    bx = (210 - bill_w) / 2
    by = (297 - bill_h) / 2 - 20  # nudge up so it sits in the upper portion

    _draw_sp_bill_template(c, bill, bx, by, scale=scale)
    c.save()
    return buf.getvalue()


def render_bills_9up_pdf(db: Session, bills: Iterable[Bill]) -> bytes:
    """Render 9 SP Gas Agency bills per A4 page (3 cols × 3 rows).

    Same template as the 6-up output, just scaled down so 9 bills fit on A4.
    """
    buf = BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)

    bills = list(bills)
    if not bills:
        c.setFont("Helvetica", 12)
        c.drawString(MARGIN, PAGE_H - MARGIN - 10, "No bills in the selected range.")
        c.save()
        return buf.getvalue()

    # 3×3 grid on A4 (210×297mm). Logical bill is 95×92mm; pick scale so it
    # fits the cell, then size cells from that scale (no wasted gaps).
    page_margin_x = 6.0  # mm
    page_margin_y = 6.0
    col_gap = 3.0
    row_gap = 3.0
    cell_w_mm = (210 - 2 * page_margin_x - 2 * col_gap) / 3   # ≈ 64.7mm
    cell_h_mm = (297 - 2 * page_margin_y - 2 * row_gap) / 3   # ≈ 93.0mm
    scale = min(cell_w_mm / 95.0, cell_h_mm / 92.0)
    bill_w = 95 * scale
    bill_h = 92 * scale

    col_lefts = [page_margin_x + i * (cell_w_mm + col_gap) for i in range(3)]
    row_tops = [page_margin_y + i * (cell_h_mm + row_gap) for i in range(3)]

    for index, bill in enumerate(bills):
        pos = index % 9
        if pos == 0 and index > 0:
            c.showPage()
        col = pos % 3
        row = pos // 3
        # Center the bill within its cell
        bx = col_lefts[col] + (cell_w_mm - bill_w) / 2
        by = row_tops[row] + (cell_h_mm - bill_h) / 2
        _draw_sp_bill_template(c, bill, bx, by, scale=scale)

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
        village = (customer.village or "")[:14]
        sep = " — " if village else ""
        c.drawString(x + pad, ty, f"{(customer.name or '')[:28]}{sep}{village}")
        ty -= 3 * mm
        c.setFont("Helvetica", 7)
        c.drawString(x + pad, ty, f"Mob: {customer.mobile or ''}")
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
