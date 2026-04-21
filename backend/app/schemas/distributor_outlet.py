from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


class DOBase(BaseModel):
    code: str = Field(..., max_length=10, min_length=1)
    owner_name: str = Field(..., max_length=150, min_length=1)
    location: str = Field(..., max_length=150, min_length=1)

    @field_validator("code")
    @classmethod
    def upper_trim(cls, v: str) -> str:
        return v.strip().upper()

    @field_validator("owner_name", "location")
    @classmethod
    def trim(cls, v: str) -> str:
        return v.strip()


class DOCreate(DOBase):
    is_active: bool = True


class DOUpdate(BaseModel):
    code: Optional[str] = Field(None, max_length=10, min_length=1)
    owner_name: Optional[str] = Field(None, max_length=150, min_length=1)
    location: Optional[str] = Field(None, max_length=150, min_length=1)
    is_active: Optional[bool] = None

    @field_validator("code")
    @classmethod
    def upper_trim(cls, v: Optional[str]) -> Optional[str]:
        return v.strip().upper() if v else v

    @field_validator("owner_name", "location")
    @classmethod
    def trim(cls, v: Optional[str]) -> Optional[str]:
        return v.strip() if v else v


class DORead(DOBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    is_active: bool
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class DOSearchResult(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    owner_name: str
    location: str
    is_active: bool
