from datetime import date

from fastapi import APIRouter, Depends, Query
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
