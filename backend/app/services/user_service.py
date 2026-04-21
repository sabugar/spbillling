from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.audit import AuditAction
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.utils.audit import write_audit
from app.utils.auth import hash_password


def list_users(db: Session):
    return select(User).order_by(User.username)


def get_user(db: Session, user_id: int) -> User:
    u = db.get(User, user_id)
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
    return u


def create_user(db: Session, payload: UserCreate, actor_id: int) -> User:
    if db.scalar(select(User).where(User.username == payload.username)):
        raise HTTPException(status_code=400, detail="Username already exists")
    if payload.email and db.scalar(select(User).where(User.email == payload.email)):
        raise HTTPException(status_code=400, detail="Email already exists")
    u = User(
        username=payload.username,
        email=payload.email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name,
        role=payload.role,
        is_active=payload.is_active,
    )
    db.add(u)
    db.flush()
    write_audit(db, entity_type="user", entity_id=u.id,
                action=AuditAction.CREATE, user_id=actor_id,
                changes={"username": u.username, "role": u.role.value})
    db.commit()
    db.refresh(u)
    return u


def update_user(db: Session, user_id: int, payload: UserUpdate, actor_id: int) -> User:
    u = get_user(db, user_id)
    data = payload.model_dump(exclude_unset=True)
    if "password" in data and data["password"]:
        u.password_hash = hash_password(data.pop("password"))
    for k, v in data.items():
        setattr(u, k, v)
    write_audit(db, entity_type="user", entity_id=u.id,
                action=AuditAction.UPDATE, user_id=actor_id)
    db.commit()
    db.refresh(u)
    return u


def deactivate_user(db: Session, user_id: int, actor_id: int) -> None:
    u = get_user(db, user_id)
    u.is_active = False
    write_audit(db, entity_type="user", entity_id=u.id,
                action=AuditAction.DELETE, user_id=actor_id)
    db.commit()
