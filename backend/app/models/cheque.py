import enum
from datetime import date
from decimal import Decimal
from typing import Optional

from sqlalchemy import Date, Enum, ForeignKey, Index, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class ChequeStatus(str, enum.Enum):
    PENDING = "pending"
    CLEARED = "cleared"
    BOUNCED = "bounced"
    CANCELLED = "cancelled"


class Cheque(Base, TimestampMixin):
    __tablename__ = "cheques"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    cheque_number: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    bank_name: Mapped[str] = mapped_column(String(100), nullable=False)
    branch_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    cheque_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)

    customer_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("customers.id", ondelete="SET NULL"), nullable=True, index=True
    )
    bill_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("bills.id", ondelete="SET NULL"), nullable=True, index=True
    )
    payment_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("payments.id", ondelete="SET NULL"), nullable=True, index=True
    )

    status: Mapped[ChequeStatus] = mapped_column(
        Enum(ChequeStatus, name="cheque_status", native_enum=False, length=16),
        default=ChequeStatus.PENDING,
        nullable=False,
        index=True,
    )
    cleared_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    bounce_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    created_by_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    __table_args__ = (
        Index("ix_cheques_status_date", "status", "cheque_date"),
    )
