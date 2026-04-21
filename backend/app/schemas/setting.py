from typing import Optional

from pydantic import BaseModel, ConfigDict


class SettingBase(BaseModel):
    key: str
    value: Optional[str] = None
    description: Optional[str] = None


class SettingUpsert(BaseModel):
    value: Optional[str] = None
    description: Optional[str] = None


class SettingOut(SettingBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
