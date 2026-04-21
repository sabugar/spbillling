from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


# ---------- Category ----------
class CategoryBase(BaseModel):
    name: str = Field(..., max_length=100)
    description: Optional[str] = None
    display_order: int = 0
    is_active: bool = True


class CategoryCreate(CategoryBase):
    pass


class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    display_order: Optional[int] = None
    is_active: Optional[bool] = None


class CategoryOut(CategoryBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime


# ---------- Variant ----------
class VariantBase(BaseModel):
    name: str = Field(..., max_length=150)
    sku_code: Optional[str] = Field(None, max_length=50)
    unit_price: Decimal = Decimal("0")
    cost_price: Decimal = Decimal("0")
    deposit_amount: Decimal = Decimal("0")
    gst_rate: Decimal = Decimal("0")
    stock_quantity: int = 0
    is_active: bool = True


class VariantCreate(VariantBase):
    product_id: int


class VariantUpdate(BaseModel):
    name: Optional[str] = None
    sku_code: Optional[str] = None
    unit_price: Optional[Decimal] = None
    cost_price: Optional[Decimal] = None
    deposit_amount: Optional[Decimal] = None
    gst_rate: Optional[Decimal] = None
    stock_quantity: Optional[int] = None
    is_active: Optional[bool] = None


class VariantOut(VariantBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    created_at: datetime


# ---------- Product ----------
class ProductBase(BaseModel):
    name: str = Field(..., max_length=150)
    description: Optional[str] = None
    is_returnable: bool = False
    hsn_code: Optional[str] = None
    unit_of_measure: str = "Pcs"
    is_active: bool = True


class ProductCreate(ProductBase):
    category_id: int


class ProductUpdate(BaseModel):
    category_id: Optional[int] = None
    name: Optional[str] = None
    description: Optional[str] = None
    is_returnable: Optional[bool] = None
    hsn_code: Optional[str] = None
    unit_of_measure: Optional[str] = None
    is_active: Optional[bool] = None


class ProductOut(ProductBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    category_id: int
    created_at: datetime


class ProductWithVariants(ProductOut):
    variants: list[VariantOut] = []
