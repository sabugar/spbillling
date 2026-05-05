from datetime import date
from typing import Optional

from fastapi import APIRouter, Body, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.bill import BillStatus
from app.models.user import User
from app.schemas.bill import BillCreate, BillOut, BillSummary, BillUpdate
from app.schemas.common import APIResponse, PaginatedResponse
from app.schemas.report import CustomerLedger
from app.services import billing_service
from app.services.pdf_service import (
    render_bill_pdf,
    render_bill_sp_single_pdf,
    render_bills_9up_pdf,
    render_bills_preprinted_overlay_pdf,
)
from app.utils.auth import get_current_user, require_admin, require_staff
from app.utils.pagination import paginate

router = APIRouter(prefix="/bills", tags=["Bills"])


@router.get("", response_model=PaginatedResponse[BillSummary])
def list_bills(
    customer_id: Optional[int] = None,
    from_date: Optional[date] = Query(None, alias="from"),
    to_date: Optional[date] = Query(None, alias="to"),
    status: Optional[BillStatus] = None,
    bill_number_from: Optional[str] = Query(None),
    bill_number_to: Optional[str] = Query(None),
    do_id: Optional[int] = Query(None),
    city: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    stmt = billing_service.list_bills(
        db, customer_id=customer_id, from_date=from_date, to_date=to_date, status=status,
        bill_number_from=bill_number_from, bill_number_to=bill_number_to,
        do_id=do_id, city=city,
    )
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=BillSummary)


@router.post("", response_model=APIResponse[BillOut])
def create_bill(payload: BillCreate, db: Session = Depends(get_db),
                user: User = Depends(require_staff)):
    bill = billing_service.create_bill(db, payload, user.id)
    return APIResponse(data=BillOut.model_validate(bill), message="Bill created")


@router.get("/next-number", response_model=APIResponse[dict])
def next_bill_number(
    bill_date: Optional[date] = Query(None),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    bd = bill_date or date.today()
    number = billing_service._next_bill_number(db, bd)
    return APIResponse(data={"bill_number": number, "bill_date": bd.isoformat()})


@router.get("/{bill_id}", response_model=APIResponse[BillOut])
def get_bill(bill_id: int, db: Session = Depends(get_db),
             _user: User = Depends(get_current_user)):
    bill = billing_service.get_bill(db, bill_id)
    return APIResponse(data=BillOut.model_validate(bill))


@router.put("/{bill_id}", response_model=APIResponse[BillOut])
def update_bill(bill_id: int, payload: BillUpdate, db: Session = Depends(get_db),
                user: User = Depends(require_staff)):
    bill = billing_service.update_bill(db, bill_id, payload, user.id)
    return APIResponse(data=BillOut.model_validate(bill), message="Bill updated")


@router.delete("/{bill_id}", response_model=APIResponse[dict])
def delete_bill(bill_id: int, db: Session = Depends(get_db),
                user: User = Depends(require_admin)):
    """Hard-delete the bill so its number is free for the next bill.
    Side-effects (customer balance, empty-bottle ledger, stock, cheques,
    bill-linked payments) are reversed first."""
    result = billing_service.delete_bill_hard(db, bill_id, user.id)
    return APIResponse(
        data=result,
        message=f"Deleted bill {result['bill_number']} — slot is free again",
    )


@router.post("/bulk-delete", response_model=APIResponse[dict])
def bulk_delete_bills(
    ids: list[int] = Body(..., embed=True, min_length=1),
    db: Session = Depends(get_db),
    user: User = Depends(require_admin),
):
    result = billing_service.bulk_delete_bills(db, ids, user.id)
    return APIResponse(
        data=result,
        message=f"Deleted {result['deleted']} bills · "
                f"skipped {result['skipped']}",
    )


@router.get("/{bill_id}/pdf")
def bill_pdf(bill_id: int, db: Session = Depends(get_db),
             _user: User = Depends(get_current_user)):
    bill = billing_service.get_bill(db, bill_id)
    pdf_bytes = render_bill_sp_single_pdf(bill)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{bill.bill_number.replace("/", "_")}.pdf"'},
    )


@router.get("/print/batch")
def print_batch(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    format: str = Query("9up", pattern="^(9up|single|preprinted)$"),
    do_id: Optional[int] = Query(None),
    city: Optional[str] = Query(None),
    bill_number_from: Optional[str] = Query(None),
    bill_number_to: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    stmt = billing_service.list_bills(
        db, from_date=from_date, to_date=to_date,
        status=BillStatus.CONFIRMED,
        do_id=do_id, city=city,
        bill_number_from=bill_number_from, bill_number_to=bill_number_to,
    )
    bills = list(db.scalars(stmt).all())
    # PDF prints in ascending order (0001, 0002, …) so the first page holds
    # the earliest serials and the last page holds the latest.
    bills.sort(key=lambda b: (b.bill_date, b.bill_number))
    if format == "preprinted":
        pdf_bytes = render_bills_preprinted_overlay_pdf(db, bills)
        filename = "bills-preprinted.pdf"
    elif format == "9up":
        pdf_bytes = render_bills_9up_pdf(db, bills)
        filename = "bills.pdf"
    else:
        pdf_bytes = b""
        filename = "bills.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{filename}"'},
    )


@router.get("/customer/{customer_id}/ledger", response_model=APIResponse[CustomerLedger])
def customer_ledger(customer_id: int, db: Session = Depends(get_db),
                    _user: User = Depends(get_current_user)):
    data = billing_service.customer_ledger(db, customer_id)
    return APIResponse(data=CustomerLedger(**data))


@router.post("/reset", response_model=APIResponse[dict])
def reset_all_bills(
    confirm: str = Body(..., embed=True),
    db: Session = Depends(get_db),
    user: User = Depends(require_admin),
):
    """Hard-delete every bill so numbering restarts at 0001. Caller must send
    `{"confirm": "RESET"}` so this can never be triggered by accident."""
    if confirm != "RESET":
        raise HTTPException(
            status_code=400,
            detail='To confirm, send {"confirm": "RESET"}',
        )
    result = billing_service.reset_all_bills(db, user.id)
    return APIResponse(
        data=result,
        message=f"Deleted {result['bills_deleted']} bills · "
                f"{result['customers_reset']} customer balances reset",
    )


@router.post("/import", response_model=APIResponse[dict])
async def import_bills(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_staff),
):
    content = await file.read()
    result = billing_service.import_bills_from_excel(db, content, user.id)
    db.commit()
    errors = result.get("errors", [])
    return APIResponse(
        data=result,
        message=f"Imported {result['imported']} bills"
                f"{f' · {len(errors)} errors' if errors else ''}",
    )
