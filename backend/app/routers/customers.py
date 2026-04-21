from typing import Optional

from fastapi import APIRouter, Depends, File, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.customer import CustomerStatus, CustomerType
from app.models.user import User
from app.schemas.common import APIResponse, PaginatedResponse
from app.schemas.customer import (
    CustomerCreate, CustomerImportResult, CustomerOut, CustomerSearchResult, CustomerUpdate,
)
from app.services import customer_service
from app.utils.auth import get_current_user, require_admin, require_staff
from app.utils.pagination import paginate

router = APIRouter(prefix="/customers", tags=["Customers"])


@router.get("", response_model=PaginatedResponse[CustomerOut])
def list_customers(
    q: Optional[str] = None,
    customer_type: Optional[CustomerType] = None,
    status: Optional[CustomerStatus] = None,
    village: Optional[str] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    stmt = customer_service.list_customers(
        db, q=q, customer_type=customer_type, status=status, village=village,
    )
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=CustomerOut)


@router.get("/search", response_model=APIResponse[list[CustomerSearchResult]])
def search(
    q: str = Query(..., min_length=2),
    limit: int = Query(20, ge=1, le=50),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    rows = customer_service.search_customers(db, q, limit)
    return APIResponse(data=[CustomerSearchResult.model_validate(r) for r in rows])


@router.get("/{customer_id}", response_model=APIResponse[CustomerOut])
def get_customer(
    customer_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    cust = customer_service.get_customer(db, customer_id)
    return APIResponse(data=CustomerOut.model_validate(cust))


@router.post("", response_model=APIResponse[CustomerOut])
def create_customer(
    payload: CustomerCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_staff),
):
    cust = customer_service.create_customer(db, payload, user.id)
    return APIResponse(data=CustomerOut.model_validate(cust), message="Customer created")


@router.put("/{customer_id}", response_model=APIResponse[CustomerOut])
def update_customer(
    customer_id: int,
    payload: CustomerUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_staff),
):
    cust = customer_service.update_customer(db, customer_id, payload, user.id)
    return APIResponse(data=CustomerOut.model_validate(cust), message="Customer updated")


@router.delete("/{customer_id}", response_model=APIResponse)
def delete_customer(
    customer_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(require_admin),
):
    customer_service.soft_delete_customer(db, customer_id, user.id)
    return APIResponse(message="Customer deleted")


@router.patch("/{customer_id}/active", response_model=APIResponse[CustomerOut])
def set_customer_active(
    customer_id: int,
    active: bool = Query(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_admin),
):
    cust = customer_service.set_customer_active(db, customer_id, active, user.id)
    return APIResponse(data=CustomerOut.model_validate(cust))


@router.post("/import", response_model=APIResponse[CustomerImportResult])
async def import_customers(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_staff),
):
    content = await file.read()
    result = customer_service.import_customers_from_excel(db, content, user.id)
    return APIResponse(data=result, message=f"Imported {result.imported} customers")


@router.get("/export/excel")
def export_customers(
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    data = customer_service.export_customers_to_excel(db)
    return Response(
        content=data,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=customers.xlsx"},
    )
