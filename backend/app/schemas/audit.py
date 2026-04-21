from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict

from app.models.audit import AuditAction


class AuditLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    entity_type: str
    entity_id: Optional[int] = None
    action: AuditAction
    changes: Optional[dict] = None
    user_id: Optional[int] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    created_at: datetime
