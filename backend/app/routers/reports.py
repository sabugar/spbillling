from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.user import User
from app.schemas.common import APIResponse
from app.schemas.report import (
    CashBookReport, DailySalesReport, EmptyBottleReport,
    GstReport, OutstandingReport, ProductSalesReport,
)
from app.services import report_service
from app.utils.auth import get_current_user

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.get("/dashboard", response_model=APIResponse[dict])
def dashboard(db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    return APIResponse(data=report_service.dashboard(db))


@router.get("/daily-sales", response_model=APIResponse[DailySalesReport])
def daily_sales(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    db: Session = Depends(get_db), _user: User = Depends(get_current_user),
):
    return APIResponse(data=report_service.daily_sales(db, from_date, to_date))


@router.get("/outstanding", response_model=APIResponse[OutstandingReport])
def outstanding(db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    return APIResponse(data=report_service.outstanding(db))


@router.get("/empty-bottles", response_model=APIResponse[EmptyBottleReport])
def empty_bottles(db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    return APIResponse(data=report_service.empty_bottles(db))


@router.get("/product-sales", response_model=APIResponse[ProductSalesReport])
def product_sales(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    db: Session = Depends(get_db), _user: User = Depends(get_current_user),
):
    return APIResponse(data=report_service.product_wise_sales(db, from_date, to_date))


@router.get("/cash-book", response_model=APIResponse[CashBookReport])
def cash_book(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    db: Session = Depends(get_db), _user: User = Depends(get_current_user),
):
    return APIResponse(data=report_service.cash_book(db, from_date, to_date))


@router.get("/gst", response_model=APIResponse[GstReport])
def gst(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    db: Session = Depends(get_db), _user: User = Depends(get_current_user),
):
    return APIResponse(data=report_service.gst_summary(db, from_date, to_date))


# ---------- Registers (per-day rollups) ----------

@router.get("/register/daily", response_model=APIResponse[list[dict]])
def register_daily(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    do_id: Optional[int] = None,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    """One row per day inside the range:
    `date · bill # from · bill # to · qty · total`."""
    return APIResponse(
        data=report_service.daily_register(db, from_date, to_date, do_id=do_id)
    )


@router.get("/register/do", response_model=APIResponse[list[dict]])
def register_do(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    do_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    """One row per (DO, day) inside the range — each DO grouped by day.
    Pass `do_id` to scope to a single Distributor Outlet.
    `do_code · do_name · date · bill # from · bill # to · qty · total`."""
    return APIResponse(
        data=report_service.do_register(db, from_date, to_date, do_id=do_id)
    )


# ---------- Register exports ----------
_XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


@router.get("/register/daily/export")
def export_register_daily(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    do_id: Optional[int] = Query(None),
    fmt: str = Query("excel", pattern="^(excel|pdf)$"),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    if fmt == "excel":
        data = report_service.daily_register_excel(
            db, from_date, to_date, do_id=do_id)
        return Response(
            content=data, media_type=_XLSX,
            headers={"Content-Disposition":
                     f'attachment; filename="daily-register-{from_date}-to-{to_date}.xlsx"'},
        )
    data = report_service.daily_register_pdf(
        db, from_date, to_date, do_id=do_id)
    return Response(
        content=data, media_type="application/pdf",
        headers={"Content-Disposition":
                 f'attachment; filename="daily-register-{from_date}-to-{to_date}.pdf"'},
    )


@router.get("/register/do/export")
def export_register_do(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    do_id: Optional[int] = Query(None),
    fmt: str = Query("excel", pattern="^(excel|pdf)$"),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    suffix = f"-do{do_id}" if do_id else ""
    if fmt == "excel":
        data = report_service.do_register_excel(
            db, from_date, to_date, do_id=do_id)
        return Response(
            content=data, media_type=_XLSX,
            headers={"Content-Disposition":
                     f'attachment; filename="do-register{suffix}-{from_date}-to-{to_date}.xlsx"'},
        )
    data = report_service.do_register_pdf(
        db, from_date, to_date, do_id=do_id)
    return Response(
        content=data, media_type="application/pdf",
        headers={"Content-Disposition":
                 f'attachment; filename="do-register{suffix}-{from_date}-to-{to_date}.pdf"'},
    )
