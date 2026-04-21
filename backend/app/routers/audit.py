from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.audit import AuditAction, AuditLog
from app.models.user import User
from app.schemas.audit import AuditLogOut
from app.schemas.common import PaginatedResponse
from app.utils.auth import require_admin
from app.utils.pagination import paginate

router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])


@router.get("", response_model=PaginatedResponse[AuditLogOut])
def list_audit(
    entity_type: Optional[str] = None,
    entity_id: Optional[int] = None,
    action: Optional[AuditAction] = None,
    user_id: Optional[int] = None,
    from_date: Optional[datetime] = Query(None, alias="from"),
    to_date: Optional[datetime] = Query(None, alias="to"),
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    stmt = select(AuditLog).order_by(AuditLog.created_at.desc())
    if entity_type:
        stmt = stmt.where(AuditLog.entity_type == entity_type)
    if entity_id:
        stmt = stmt.where(AuditLog.entity_id == entity_id)
    if action:
        stmt = stmt.where(AuditLog.action == action)
    if user_id:
        stmt = stmt.where(AuditLog.user_id == user_id)
    if from_date:
        stmt = stmt.where(AuditLog.created_at >= from_date)
    if to_date:
        stmt = stmt.where(AuditLog.created_at <= to_date)
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=AuditLogOut)
