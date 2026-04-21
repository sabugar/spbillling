from datetime import date
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel


class DateRangeQuery(BaseModel):
    from_date: date
    to_date: date


class DailySalesRow(BaseModel):
    date: date
    bills_count: int
    total_sales: Decimal
    cash_collected: Decimal
    cheque_collected: Decimal
    upi_collected: Decimal
    card_collected: Decimal
    credit_given: Decimal


class DailySalesReport(BaseModel):
    from_date: date
    to_date: date
    rows: list[DailySalesRow]
    grand_total_sales: Decimal
    grand_total_collected: Decimal


class OutstandingRow(BaseModel):
    customer_id: int
    customer_name: str
    mobile: str
    village: Optional[str] = None
    current_balance: Decimal
    current_empty_bottles: int


class OutstandingReport(BaseModel):
    total_customers: int
    total_outstanding: Decimal
    rows: list[OutstandingRow]


class EmptyBottleRow(BaseModel):
    customer_id: int
    customer_name: str
    mobile: str
    village: Optional[str] = None
    empty_bottles: int


class EmptyBottleReport(BaseModel):
    total_empty: int
    rows: list[EmptyBottleRow]


class ProductSalesRow(BaseModel):
    variant_id: int
    variant_name: str
    product_name: str
    qty_sold: int
    total_amount: Decimal


class ProductSalesReport(BaseModel):
    from_date: date
    to_date: date
    rows: list[ProductSalesRow]


class CashBookRow(BaseModel):
    date: date
    cash_in: Decimal
    cash_out: Decimal
    net: Decimal


class CashBookReport(BaseModel):
    from_date: date
    to_date: date
    rows: list[CashBookRow]
    total_in: Decimal
    total_out: Decimal
    net: Decimal


class GstSummaryRow(BaseModel):
    gst_rate: Decimal
    taxable_amount: Decimal
    gst_amount: Decimal
    total_amount: Decimal


class GstReport(BaseModel):
    from_date: date
    to_date: date
    rows: list[GstSummaryRow]
    total_taxable: Decimal
    total_gst: Decimal


class CustomerLedgerEntry(BaseModel):
    date: date
    type: str            # 'bill' | 'payment' | 'opening'
    reference: str       # bill_number / payment_number
    debit: Decimal       # bill total
    credit: Decimal      # payment amount
    balance: Decimal
    notes: Optional[str] = None


class CustomerLedger(BaseModel):
    customer_id: int
    customer_name: str
    mobile: str
    opening_balance: Decimal
    entries: list[CustomerLedgerEntry]
    closing_balance: Decimal
