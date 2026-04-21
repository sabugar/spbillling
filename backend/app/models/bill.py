import enum
from datetime import date
from decimal import Decimal
from typing import Optional

from sqlalchemy import (
    Date, Enum, ForeignKey, Index, Integer, JSON, Numeric, String, Text, UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class BillStatus(str, enum.Enum):
    DRAFT = "draft"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"


class PaymentMode(str, enum.Enum):
    CASH = "cash"
    CHEQUE = "cheque"
    UPI = "upi"
    CARD = "card"
    CREDIT = "credit"


class Bill(Base, TimestampMixin):
    __tablename__ = "bills"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)

    bill_number: Mapped[str] = mapped_column(String(40), unique=True, nullable=False, index=True)
    bill_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)

    customer_id: Mapped[int] = mapped_column(
        ForeignKey("customers.id", ondelete="RESTRICT"), nullable=False, index=True
    )

    subtotal: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    discount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    gst_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    total_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    amount_paid: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    balance_due: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)

    payment_mode: Mapped[PaymentMode] = mapped_column(
        Enum(PaymentMode, name="payment_mode", native_enum=False, length=16),
        default=PaymentMode.CASH,
        nullable=False,
        index=True,
    )
    cheque_details: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    status: Mapped[BillStatus] = mapped_column(
        Enum(BillStatus, name="bill_status", native_enum=False, length=16),
        default=BillStatus.CONFIRMED,
        nullable=False,
        index=True,
    )

    created_by_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )

    items: Mapped[list["BillItem"]] = relationship(
        back_populates="bill", cascade="all, delete-orphan", lazy="selectin"
    )

    __table_args__ = (
        Index("ix_bills_customer_date", "customer_id", "bill_date"),
        Index("ix_bills_date_status", "bill_date", "status"),
    )


class BillItem(Base):
    __tablename__ = "bill_items"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)

    bill_id: Mapped[int] = mapped_column(
        ForeignKey("bills.id", ondelete="CASCADE"), nullable=False, index=True
    )
    product_variant_id: Mapped[int] = mapped_column(
        ForeignKey("product_variants.id", ondelete="RESTRICT"), nullable=False, index=True
    )

    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    rate: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    empty_returned: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    gst_rate: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=0, nullable=False)
    gst_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    line_total: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)

    bill: Mapped[Bill] = relationship(back_populates="items")
