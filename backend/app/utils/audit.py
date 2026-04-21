from typing import Any, Optional

from sqlalchemy.orm import Session

from app.models.audit import AuditAction, AuditLog


def write_audit(
    db: Session,
    *,
    entity_type: str,
    entity_id: Optional[int],
    action: AuditAction,
    user_id: Optional[int],
    changes: Optional[dict[str, Any]] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
    commit: bool = False,
) -> AuditLog:
    log = AuditLog(
        entity_type=entity_type,
        entity_id=entity_id,
        action=action,
        user_id=user_id,
        changes=changes,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    db.add(log)
    if commit:
        db.commit()
    else:
        db.flush()
    return log
