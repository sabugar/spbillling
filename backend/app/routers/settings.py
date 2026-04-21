from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.user import User
from app.schemas.common import APIResponse
from app.schemas.setting import SettingOut, SettingUpsert
from app.services import setting_service
from app.utils.auth import get_current_user, require_admin

router = APIRouter(prefix="/settings", tags=["Settings"])


@router.get("", response_model=APIResponse[list[SettingOut]])
def list_settings(db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    rows = setting_service.list_settings(db)
    return APIResponse(data=[SettingOut.model_validate(r) for r in rows])


@router.get("/{key}", response_model=APIResponse[SettingOut])
def get_setting(key: str, db: Session = Depends(get_db),
                _user: User = Depends(get_current_user)):
    s = setting_service.get_setting(db, key)
    if not s:
        raise HTTPException(status_code=404, detail="Setting not found")
    return APIResponse(data=SettingOut.model_validate(s))


@router.put("/{key}", response_model=APIResponse[SettingOut])
def upsert_setting(key: str, payload: SettingUpsert, db: Session = Depends(get_db),
                   admin: User = Depends(require_admin)):
    s = setting_service.upsert_setting(db, key, payload, admin.id)
    return APIResponse(data=SettingOut.model_validate(s), message="Setting saved")


@router.delete("/{key}", response_model=APIResponse)
def delete_setting(key: str, db: Session = Depends(get_db),
                   _admin: User = Depends(require_admin)):
    setting_service.delete_setting(db, key)
    return APIResponse(message="Setting deleted")
