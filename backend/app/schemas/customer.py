from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models.customer import CustomerStatus, CustomerType


class CustomerBase(BaseModel):
    name: str = Field(..., max_length=150)
    mobile: str = Field(..., min_length=10, max_length=15)
    alternate_mobile: Optional[str] = Field(None, max_length=15)
    village: str = Field(..., max_length=100)
    city: str = Field(..., max_length=100)
    district: Optional[str] = Field(None, max_length=100)
    state: Optional[str] = Field("Gujarat", max_length=100)
    pincode: Optional[str] = Field(None, max_length=10)
    full_address: Optional[str] = None
    customer_type: CustomerType = CustomerType.DOMESTIC
    aadhaar_number: Optional[str] = Field(None, max_length=20)
    email: Optional[EmailStr] = None
    date_of_birth: Optional[date] = None
    notes: Optional[str] = None

    @field_validator("mobile", "alternate_mobile")
    @classmethod
    def digits_only(cls, v):
        if v is None:
            return v
        v = v.strip()
        if not v.isdigit():
            raise ValueError("mobile must contain digits only")
        return v


class CustomerCreate(CustomerBase):
    customer_code: Optional[str] = Field(None, max_length=32)
    registration_date: Optional[date] = None
    opening_balance: Decimal = Decimal("0")
    opening_empty_bottles: int = 0
    status: CustomerStatus = CustomerStatus.ACTIVE


class CustomerUpdate(BaseModel):
    name: Optional[str] = None
    mobile: Optional[str] = None
    alternate_mobile: Optional[str] = None
    village: Optional[str] = None
    city: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    full_address: Optional[str] = None
    customer_type: Optional[CustomerType] = None
    aadhaar_number: Optional[str] = None
    email: Optional[EmailStr] = None
    date_of_birth: Optional[date] = None
    notes: Optional[str] = None
    status: Optional[CustomerStatus] = None


class CustomerOut(CustomerBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    customer_code: Optional[str] = None
    registration_date: date
    status: CustomerStatus
    opening_balance: Decimal
    opening_empty_bottles: int
    current_balance: Decimal
    current_empty_bottles: int
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class CustomerSearchResult(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    mobile: str
    village: str
    city: str
    current_balance: Decimal
    current_empty_bottles: int


class CustomerImportError(BaseModel):
    row: int
    error: str
    data: dict


class CustomerImportResult(BaseModel):
    imported: int
    skipped: int
    errors: list[CustomerImportError]
