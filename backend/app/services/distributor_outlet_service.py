from typing import Optional

from fastapi import HTTPException
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.audit import AuditAction
from app.models.customer import Customer, CustomerStatus
from app.models.distributor_outlet import DistributorOutlet
from app.schemas.distributor_outlet import DOCreate, DOUpdate
from app.utils.audit import write_audit


def _check_code_unique(db: Session, code: str, exclude_id: Optional[int] = None) -> None:
    stmt = select(DistributorOutlet).where(
        DistributorOutlet.code == code,
        DistributorOutlet.is_deleted.is_(False),
    )
    if exclude_id:
        stmt = stmt.where(DistributorOutlet.id != exclude_id)
    if db.scalar(stmt):
        raise HTTPException(status_code=400, detail=f"DO code '{code}' already exists")


def _has_active_customers(db: Session, do_id: int) -> bool:
    return bool(db.scalar(
        select(Customer.id).where(
            Customer.do_id == do_id,
            Customer.is_deleted.is_(False),
            Customer.status == CustomerStatus.ACTIVE,
        ).limit(1)
    ))


def get_do(db: Session, do_id: int) -> DistributorOutlet:
    do = db.get(DistributorOutlet, do_id)
    if not do or do.is_deleted:
        raise HTTPException(status_code=404, detail="Distributor outlet not found")
    return do


def create_do(db: Session, payload: DOCreate, user_id: int) -> DistributorOutlet:
    _check_code_unique(db, payload.code)
    do = DistributorOutlet(
        code=payload.code,
        owner_name=payload.owner_name,
        location=payload.location,
        is_active=payload.is_active,
    )
    db.add(do)
    db.flush()
    write_audit(db, entity_type="distributor_outlet", entity_id=do.id,
                action=AuditAction.CREATE, user_id=user_id,
                changes={"code": do.code, "owner_name": do.owner_name})
    db.commit()
    db.refresh(do)
    return do


def update_do(db: Session, do_id: int, payload: DOUpdate, user_id: int) -> DistributorOutlet:
    do = get_do(db, do_id)
    data = payload.model_dump(exclude_unset=True)
    if "code" in data and data["code"] != do.code:
        _check_code_unique(db, data["code"], exclude_id=do.id)

    if data.get("is_active") is False and _has_active_customers(db, do.id):
        raise HTTPException(
            status_code=400,
            detail="Cannot deactivate: DO has active customers assigned",
        )

    changes = {}
    for k, v in data.items():
        old = getattr(do, k)
        if old != v:
            changes[k] = {"old": str(old), "new": str(v)}
            setattr(do, k, v)
    if changes:
        write_audit(db, entity_type="distributor_outlet", entity_id=do.id,
                    action=AuditAction.UPDATE, user_id=user_id, changes=changes)
    db.commit()
    db.refresh(do)
    return do


def set_active(db: Session, do_id: int, active: bool, user_id: int) -> DistributorOutlet:
    do = get_do(db, do_id)
    if not active and _has_active_customers(db, do.id):
        raise HTTPException(
            status_code=400,
            detail="Cannot deactivate: DO has active customers assigned",
        )
    do.is_active = active
    write_audit(db, entity_type="distributor_outlet", entity_id=do.id,
                action=AuditAction.UPDATE, user_id=user_id,
                changes={"is_active": active})
    db.commit()
    db.refresh(do)
    return do


def soft_delete_do(db: Session, do_id: int, user_id: int) -> None:
    do = get_do(db, do_id)
    if _has_active_customers(db, do.id):
        raise HTTPException(
            status_code=400,
            detail="Cannot delete: DO has active customers assigned",
        )
    do.is_deleted = True
    do.is_active = False
    write_audit(db, entity_type="distributor_outlet", entity_id=do.id,
                action=AuditAction.DELETE, user_id=user_id)
    db.commit()


def list_dos(
    db: Session,
    *,
    q: Optional[str] = None,
    active: Optional[bool] = None,
    include_deleted: bool = False,
):
    stmt = select(DistributorOutlet)
    if not include_deleted:
        stmt = stmt.where(DistributorOutlet.is_deleted.is_(False))
    if active is not None:
        stmt = stmt.where(DistributorOutlet.is_active.is_(active))
    if q:
        like = f"%{q.strip()}%"
        stmt = stmt.where(or_(
            DistributorOutlet.code.ilike(like),
            DistributorOutlet.owner_name.ilike(like),
            DistributorOutlet.location.ilike(like),
        ))
    stmt = stmt.order_by(DistributorOutlet.code.asc())
    return stmt


def search_dos(db: Session, q: str, limit: int = 20) -> list[DistributorOutlet]:
    if not q or len(q.strip()) < 1:
        # return top N active
        stmt = (
            select(DistributorOutlet)
            .where(DistributorOutlet.is_deleted.is_(False),
                   DistributorOutlet.is_active.is_(True))
            .order_by(DistributorOutlet.code.asc())
            .limit(limit)
        )
        return list(db.scalars(stmt).all())
    like = f"%{q.strip()}%"
    stmt = (
        select(DistributorOutlet)
        .where(
            DistributorOutlet.is_deleted.is_(False),
            DistributorOutlet.is_active.is_(True),
            or_(
                DistributorOutlet.code.ilike(like),
                DistributorOutlet.owner_name.ilike(like),
                DistributorOutlet.location.ilike(like),
            ),
        )
        .order_by(DistributorOutlet.code.asc())
        .limit(limit)
    )
    return list(db.scalars(stmt).all())
