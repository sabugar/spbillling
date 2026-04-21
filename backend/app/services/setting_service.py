from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.setting import Setting
from app.schemas.setting import SettingUpsert


def list_settings(db: Session) -> list[Setting]:
    return list(db.scalars(select(Setting).order_by(Setting.key)).all())


def get_setting(db: Session, key: str) -> Setting | None:
    return db.scalar(select(Setting).where(Setting.key == key))


def upsert_setting(db: Session, key: str, payload: SettingUpsert, user_id: int) -> Setting:
    s = get_setting(db, key)
    if s:
        s.value = payload.value
        s.description = payload.description or s.description
        s.updated_by_id = user_id
    else:
        s = Setting(key=key, value=payload.value, description=payload.description,
                    updated_by_id=user_id)
        db.add(s)
    db.commit()
    db.refresh(s)
    return s


def delete_setting(db: Session, key: str) -> None:
    s = get_setting(db, key)
    if s:
        db.delete(s)
        db.commit()
