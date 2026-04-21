import enum
from datetime import date
from decimal import Decimal
from typing import Optional

from sqlalchemy import Date, Enum, ForeignKey, Index, JSON, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin
from app.models.bill import PaymentMode


class PaymentStatus(str, enum.Enum):
    PENDING = "pending"
    CLEARED = "cleared"
    BOUNCED = "bounced"
    CANCELLED = "cancelled"


class Payment(Base, TimestampMixin):
    __tablename__ = "payments"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    payment_number: Mapped[str] = mapped_column(String(40), unique=True, nullable=False, index=True)
    payment_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)

    customer_id: Mapped[int] = mapped_column(
        ForeignKey("customers.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    reference_bill_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("bills.id", ondelete="SET NULL"), nullable=True, index=True
    )

    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    payment_mode: Mapped[PaymentMode] = mapped_column(
        Enum(PaymentMode, name="payment_mode", native_enum=False, length=16),
        default=PaymentMode.CASH,
        nullable=False,
        index=True,
    )
    cheque_details: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    status: Mapped[PaymentStatus] = mapped_column(
        Enum(PaymentStatus, name="payment_status", native_enum=False, length=16),
        default=PaymentStatus.CLEARED,
        nullable=False,
        index=True,
    )

    created_by_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    __table_args__ = (
        Index("ix_payments_customer_date", "customer_id", "payment_date"),
    )
