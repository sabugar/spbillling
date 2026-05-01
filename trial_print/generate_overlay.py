"""
Pre-printed sheet ke upar overlay print karne wala trial PDF generator.

Workflow:
  1. python generate_overlay.py
  2. overlay_test.pdf khulega — usse pre-printed sheet par print karo (ya plain A4 par)
  3. Mismatch dekho — neeche LAYOUT section ke constants adjust karo
     +X = right, +Y = neeche (1 unit = 1 mm)
  4. Re-run script. Repeat till alignment perfect.
"""

import os
import subprocess
import sys
from dataclasses import dataclass

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

PAGE_W, PAGE_H = A4  # 210mm x 297mm in points

# =============================================================================
# LAYOUT (MM) — alignment trial ke baad inhi numbers ko adjust karo
# =============================================================================

# Each ROW ka top-edge Y (mm from A4 top). 3 rows = 3 entries.
# Agar koi row upar/neeche ho to YE adjust karo (us row ka first entry).
ROW_TOPS = [8.0, 105.0, 200.0]

# Each COLUMN ka left-edge X (mm from A4 left). 2 cols = 2 entries.
COL_LEFTS = [8.0, 110.0]

# Bill ki nominal width/height (sirf debug guide rectangle ke liye)
BILL_W = 92.0
BILL_H = 92.0

# Field positions inside ONE bill (offset from bill top-left, mm)
# Y = where text BASELINE sits (i.e., bottom of letters)
DO_NAME_X, DO_NAME_Y = 26.0, 42.0
BILL_NO_X, BILL_NO_Y = 22.0, 50.0
DATE_X, DATE_Y = 70.0, 50.0
CONSUMER_X, CONSUMER_Y = 35.0, 58.0
ADDRESS_X, ADDRESS_Y = 22.0, 66.0

# Per-row Y offset (mm) — top 4 bills (rows 0,1) need slight UP, bottom 2 (row 2) different.
# Index = row number (0, 1, 2). +ve = niche, -ve = upar.
DO_NAME_ROW_OFFSET = [-1.0, -1.0, 0.0]   # rows 0,1 slight up; row 2 sahi
BILL_NO_ROW_OFFSET = [-1.0, -1.0, +1.5]  # rows 0,1 up; row 2 down
DATE_ROW_OFFSET = [-1.0, -1.0, +1.5]     # same as Bill No
CONSUMER_ROW_OFFSET = [-1.0, -1.0, +1.5] # same pattern
ADDRESS_ROW_OFFSET = [-1.5, -1.5, 0.0]   # rows 0,1 slight up; row 2 sahi

# Cost of Gas wali line ke saamne, Rs/Ps columns
AMOUNT_RS_X = 70.0
AMOUNT_PS_X = 84.0
AMOUNT_Y = 85.0

# GST blank row — single combined string: "CGST(5%) X.XX + SGST(5%) Y.YY"
GST_X = 4.0
GST_Y = 95.0

# Fonts
FONT_NAME = "Helvetica"
FONT_NAME_BOLD = "Helvetica-Bold"
FONT_SIZE = 9
FONT_SIZE_SMALL = 7
FONT_SIZE_AMOUNT = 11   # Cost of Gas amount thoda bigger
FONT_SIZE_GST = 9       # GST line — thoda bada

# Set True to draw thin grey outline around each bill slot — helpful for
# alignment debugging on plain A4. False for final pre-printed sheet print.
DEBUG_GUIDES = True

# =============================================================================


@dataclass
class Bill:
    do_name_code: str
    bill_no: str
    date: str
    consumer: str
    address: str
    amount_rs: str
    amount_ps: str
    cgst_rs: str
    cgst_ps: str
    sgst_rs: str
    sgst_ps: str


SAMPLE_BILLS = [
    Bill("1234 / SPG-A", "BILL/26-27/0001", "25-04-2026",
         "Manoj Patel", "Ranasan, Himatnagar",
         "1047", "62", "52", "38", "52", "38"),
    Bill("1235 / SPG-B", "BILL/26-27/0002", "25-04-2026",
         "Rakesh Shah", "Gambhoi Road, Idar",
         "1047", "62", "52", "38", "52", "38"),
    Bill("1236 / SPG-A", "BILL/26-27/0003", "25-04-2026",
         "Suresh Bhai", "Khedbrahma",
         "1047", "62", "52", "38", "52", "38"),
    Bill("1237 / SPG-C", "BILL/26-27/0004", "25-04-2026",
         "Hitesh Patel", "Sabarkantha",
         "1047", "62", "52", "38", "52", "38"),
    Bill("1238 / SPG-A", "BILL/26-27/0005", "25-04-2026",
         "Jignesh Shah", "Himatnagar - 383001",
         "1047", "62", "52", "38", "52", "38"),
    Bill("1239 / SPG-B", "BILL/26-27/0006", "25-04-2026",
         "Bharat Modi", "Idar Highway Road",
         "1047", "62", "52", "38", "52", "38"),
]


def bill_origin(col: int, row: int) -> tuple[float, float]:
    """Return (x, y_from_top) in mm of the bill's top-left corner on A4."""
    return COL_LEFTS[col], ROW_TOPS[row]


def to_pdf_coords(bill_x: float, bill_y_from_top: float,
                  field_x: float, field_y: float) -> tuple[float, float]:
    """Map (bill top-left + field offset, mm-from-top) → reportlab pts (Y from bottom)."""
    abs_x_mm = bill_x + field_x
    abs_y_from_top_mm = bill_y_from_top + field_y
    abs_y_from_bottom_mm = 297 - abs_y_from_top_mm
    return abs_x_mm * mm, abs_y_from_bottom_mm * mm


def draw_bill(c: canvas.Canvas, col: int, row: int, b: Bill) -> None:
    bx, by = bill_origin(col, row)

    if DEBUG_GUIDES:
        x0, y0 = to_pdf_coords(bx, by, 0, 0)
        x1, y1 = to_pdf_coords(bx, by, BILL_W, BILL_H)
        c.setStrokeColorRGB(0.85, 0.85, 0.85)
        c.setLineWidth(0.3)
        c.rect(x0, y1, x1 - x0, y0 - y1)
        c.setStrokeColorRGB(0.6, 0.6, 0.6)
        c.line(x0 - 2, y0, x0 + 2, y0)
        c.line(x0, y0 - 2, x0, y0 + 2)

    c.setFillColorRGB(0, 0, 0)

    def put(field_x: float, field_y: float, text: str,
            font: str = FONT_NAME, size: int = FONT_SIZE):
        c.setFont(font, size)
        x, y = to_pdf_coords(bx, by, field_x, field_y)
        c.drawString(x, y, text)

    put(DO_NAME_X, DO_NAME_Y + DO_NAME_ROW_OFFSET[row], b.do_name_code)
    put(BILL_NO_X, BILL_NO_Y + BILL_NO_ROW_OFFSET[row], b.bill_no, FONT_NAME_BOLD, FONT_SIZE)
    put(DATE_X, DATE_Y + DATE_ROW_OFFSET[row], b.date)
    put(CONSUMER_X, CONSUMER_Y + CONSUMER_ROW_OFFSET[row], b.consumer)
    put(ADDRESS_X, ADDRESS_Y + ADDRESS_ROW_OFFSET[row], b.address)

    # Cost of Gas line
    put(AMOUNT_RS_X, AMOUNT_Y, b.amount_rs, FONT_NAME_BOLD, FONT_SIZE_AMOUNT)
    put(AMOUNT_PS_X, AMOUNT_Y, b.amount_ps, FONT_NAME_BOLD, FONT_SIZE_AMOUNT)

    # GST: single combined string  "CGST(5%) X.XX + SGST(5%) Y.YY"
    gst_text = (
        f"CGST(5%) {b.cgst_rs}.{b.cgst_ps}"
        f"  +  SGST(5%) {b.sgst_rs}.{b.sgst_ps}"
    )
    put(GST_X, GST_Y, gst_text, FONT_NAME_BOLD, FONT_SIZE_GST)


def main(output: str) -> None:
    c = canvas.Canvas(output, pagesize=A4)
    for idx, bill in enumerate(SAMPLE_BILLS):
        col = idx % 2
        row = idx // 2
        draw_bill(c, col, row, bill)
    c.showPage()
    c.save()
    print(f"Generated: {output}")


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "overlay_test.pdf")
    main(out)
    if sys.platform == "win32":
        os.startfile(out)
    else:
        subprocess.run(["xdg-open", out], check=False)
