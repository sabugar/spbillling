import enum
from datetime import date
from decimal import Decimal
from typing import Optional

from sqlalchemy import (
    Boolean, Date, Enum, ForeignKey, Index, Integer, Numeric, String, Text, UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
from app.models.distributor_outlet import DistributorOutlet  # noqa: F401 (relationship target)


class CustomerType(str, enum.Enum):
    DOMESTIC = "domestic"
    COMMERCIAL = "commercial"


class CustomerStatus(str, enum.Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"


class Customer(Base, TimestampMixin):
    __tablename__ = "customers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    consumer_number: Mapped[Optional[str]] = mapped_column(String(32), unique=True, nullable=True, index=True)

    do_id: Mapped[int] = mapped_column(
        ForeignKey("distributor_outlets.id", ondelete="RESTRICT"),
        nullable=False, index=True,
    )

    name: Mapped[str] = mapped_column(String(150), nullable=False)
    mobile: Mapped[str] = mapped_column(String(15), nullable=False, index=True)
    alternate_mobile: Mapped[Optional[str]] = mapped_column(String(15), nullable=True)

    village: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, index=True)
    city: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    district: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    state: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, default="Gujarat")
    pincode: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    full_address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    customer_type: Mapped[CustomerType] = mapped_column(
        Enum(CustomerType, name="customer_type", native_enum=False, length=16),
        default=CustomerType.DOMESTIC,
        nullable=False,
        index=True,
    )

    aadhaar_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    date_of_birth: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    registration_date: Mapped[date] = mapped_column(Date, nullable=False)

    status: Mapped[CustomerStatus] = mapped_column(
        Enum(CustomerStatus, name="customer_status", native_enum=False, length=16),
        default=CustomerStatus.ACTIVE,
        nullable=False,
        index=True,
    )

    opening_balance: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    opening_empty_bottles: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    current_balance: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    current_empty_bottles: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    created_by_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )

    distributor_outlet: Mapped["DistributorOutlet"] = relationship(
        "DistributorOutlet", lazy="joined"
    )

    __table_args__ = (
        Index("ix_customers_status_deleted", "status", "is_deleted"),
        Index("ix_customers_mobile_deleted", "mobile", "is_deleted"),
    )
