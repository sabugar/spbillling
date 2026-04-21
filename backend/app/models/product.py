from decimal import Decimal
from typing import Optional

from sqlalchemy import Boolean, ForeignKey, Index, Integer, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductCategory(Base, TimestampMixin):
    __tablename__ = "product_categories"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    products: Mapped[list["Product"]] = relationship(back_populates="category")


class Product(Base, TimestampMixin):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("product_categories.id", ondelete="RESTRICT"), nullable=False, index=True
    )

    name: Mapped[str] = mapped_column(String(150), nullable=False, index=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_returnable: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    hsn_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    unit_of_measure: Mapped[str] = mapped_column(String(20), default="Pcs", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)

    category: Mapped[ProductCategory] = relationship(back_populates="products")
    variants: Mapped[list["ProductVariant"]] = relationship(
        back_populates="product", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("ix_products_category_active", "category_id", "is_active"),
    )


class ProductVariant(Base, TimestampMixin):
    __tablename__ = "product_variants"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    product_id: Mapped[int] = mapped_column(
        ForeignKey("products.id", ondelete="CASCADE"), nullable=False, index=True
    )

    name: Mapped[str] = mapped_column(String(150), nullable=False, index=True)
    sku_code: Mapped[Optional[str]] = mapped_column(String(50), unique=True, nullable=True, index=True)

    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    cost_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    deposit_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    gst_rate: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=0, nullable=False)

    stock_quantity: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    product: Mapped[Product] = relationship(back_populates="variants")

    __table_args__ = (
        Index("ix_variants_product_active", "product_id", "is_active"),
    )
