import enum
from typing import Optional

from sqlalchemy import Enum, ForeignKey, Index, Integer, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class EmptyBottleTxnType(str, enum.Enum):
    ISSUED = "issued"           # customer received a cylinder (owes empty back)
    RETURNED = "returned"       # customer returned an empty
    ADJUSTMENT = "adjustment"   # manual correction
    OPENING = "opening"         # opening balance setup


class EmptyBottleTransaction(Base, TimestampMixin):
    __tablename__ = "empty_bottle_transactions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    customer_id: Mapped[int] = mapped_column(
        ForeignKey("customers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    bill_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("bills.id", ondelete="SET NULL"), nullable=True, index=True
    )

    transaction_type: Mapped[EmptyBottleTxnType] = mapped_column(
        Enum(EmptyBottleTxnType, name="empty_bottle_txn_type", native_enum=False, length=16),
        nullable=False,
        index=True,
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)  # signed: +issued, -returned
    balance_after: Mapped[int] = mapped_column(Integer, nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    created_by_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    __table_args__ = (
        Index("ix_empty_bottle_customer_created", "customer_id", "created_at"),
    )
