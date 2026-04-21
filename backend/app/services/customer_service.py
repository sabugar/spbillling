from datetime import date
from decimal import Decimal
from io import BytesIO
from typing import Optional

from fastapi import HTTPException
from openpyxl import Workbook, load_workbook
from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session

from app.models.audit import AuditAction
from app.models.customer import Customer, CustomerStatus, CustomerType
from app.models.empty_bottle import EmptyBottleTransaction, EmptyBottleTxnType
from app.schemas.customer import (
    CustomerCreate, CustomerImportError, CustomerImportResult, CustomerUpdate,
)
from app.utils.audit import write_audit


def _check_mobile_village_unique(
    db: Session, mobile: str, village: str, exclude_id: Optional[int] = None
) -> None:
    stmt = select(Customer).where(
        Customer.mobile == mobile,
        Customer.village == village,
        Customer.is_deleted.is_(False),
    )
    if exclude_id:
        stmt = stmt.where(Customer.id != exclude_id)
    if db.scalar(stmt):
        raise HTTPException(
            status_code=400,
            detail=f"Customer already exists with mobile {mobile} in {village}",
        )


def create_customer(db: Session, payload: CustomerCreate, user_id: int) -> Customer:
    _check_mobile_village_unique(db, payload.mobile, payload.village)

    cust = Customer(
        customer_code=payload.customer_code,
        name=payload.name,
        mobile=payload.mobile,
        alternate_mobile=payload.alternate_mobile,
        village=payload.village,
        city=payload.city,
        district=payload.district,
        state=payload.state or "Gujarat",
        pincode=payload.pincode,
        full_address=payload.full_address,
        customer_type=payload.customer_type,
        aadhaar_number=payload.aadhaar_number,
        email=payload.email,
        date_of_birth=payload.date_of_birth,
        notes=payload.notes,
        registration_date=payload.registration_date or date.today(),
        status=payload.status,
        opening_balance=payload.opening_balance,
        opening_empty_bottles=payload.opening_empty_bottles,
        current_balance=payload.opening_balance,
        current_empty_bottles=payload.opening_empty_bottles,
        created_by_id=user_id,
    )
    db.add(cust)
    db.flush()

    if payload.opening_empty_bottles:
        db.add(EmptyBottleTransaction(
            customer_id=cust.id,
            transaction_type=EmptyBottleTxnType.OPENING,
            quantity=payload.opening_empty_bottles,
            balance_after=payload.opening_empty_bottles,
            notes="Opening balance",
            created_by_id=user_id,
        ))

    write_audit(db, entity_type="customer", entity_id=cust.id,
                action=AuditAction.CREATE, user_id=user_id,
                changes={"name": cust.name, "mobile": cust.mobile})
    db.commit()
    db.refresh(cust)
    return cust


def update_customer(db: Session, customer_id: int, payload: CustomerUpdate, user_id: int) -> Customer:
    cust = get_customer(db, customer_id)
    data = payload.model_dump(exclude_unset=True)

    if "mobile" in data or "village" in data:
        new_mobile = data.get("mobile", cust.mobile)
        new_village = data.get("village", cust.village)
        _check_mobile_village_unique(db, new_mobile, new_village, exclude_id=cust.id)

    changes = {}
    for k, v in data.items():
        old = getattr(cust, k)
        if old != v:
            changes[k] = {"old": str(old) if old is not None else None, "new": str(v) if v is not None else None}
            setattr(cust, k, v)

    if changes:
        write_audit(db, entity_type="customer", entity_id=cust.id,
                    action=AuditAction.UPDATE, user_id=user_id, changes=changes)
    db.commit()
    db.refresh(cust)
    return cust


def get_customer(db: Session, customer_id: int) -> Customer:
    cust = db.get(Customer, customer_id)
    if not cust or cust.is_deleted:
        raise HTTPException(status_code=404, detail="Customer not found")
    return cust


def soft_delete_customer(db: Session, customer_id: int, user_id: int) -> None:
    cust = get_customer(db, customer_id)
    cust.is_deleted = True
    cust.status = CustomerStatus.INACTIVE
    write_audit(db, entity_type="customer", entity_id=cust.id,
                action=AuditAction.DELETE, user_id=user_id)
    db.commit()


def list_customers(
    db: Session,
    *,
    q: Optional[str] = None,
    customer_type: Optional[CustomerType] = None,
    status: Optional[CustomerStatus] = None,
    village: Optional[str] = None,
    include_deleted: bool = False,
):
    stmt = select(Customer)
    if not include_deleted:
        stmt = stmt.where(Customer.is_deleted.is_(False))
    if q:
        like = f"%{q}%"
        stmt = stmt.where(or_(
            Customer.name.ilike(like),
            Customer.mobile.ilike(like),
            Customer.village.ilike(like),
            Customer.city.ilike(like),
        ))
    if customer_type:
        stmt = stmt.where(Customer.customer_type == customer_type)
    if status:
        stmt = stmt.where(Customer.status == status)
    if village:
        stmt = stmt.where(Customer.village.ilike(f"%{village}%"))
    stmt = stmt.order_by(Customer.name.asc())
    return stmt


def search_customers(db: Session, q: str, limit: int = 20) -> list[Customer]:
    if not q or len(q.strip()) < 2:
        return []
    like = f"%{q.strip()}%"
    stmt = (
        select(Customer)
        .where(
            Customer.is_deleted.is_(False),
            or_(
                Customer.mobile.ilike(like),
                and_(Customer.name.ilike(like)),
                Customer.village.ilike(like),
            ),
        )
        .order_by(Customer.name.asc())
        .limit(limit)
    )
    return list(db.scalars(stmt).all())


# --------- Excel import/export ---------
IMPORT_HEADERS = ["Name", "Mobile", "Village", "City", "Type", "Opening_Balance", "Opening_Bottles"]


def import_customers_from_excel(
    db: Session, file_bytes: bytes, user_id: int
) -> CustomerImportResult:
    wb = load_workbook(BytesIO(file_bytes), read_only=True, data_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))
    if not rows:
        raise HTTPException(status_code=400, detail="Excel file is empty")

    headers = [str(c).strip() if c else "" for c in rows[0]]
    errors: list[CustomerImportError] = []
    imported = 0
    skipped = 0

    for idx, raw in enumerate(rows[1:], start=2):
        row = {headers[i]: (raw[i] if i < len(raw) else None) for i in range(len(headers))}
        try:
            name = str(row.get("Name", "") or "").strip()
            mobile = str(row.get("Mobile", "") or "").strip()
            village = str(row.get("Village", "") or "").strip()
            city = str(row.get("City", "") or "").strip()
            if not name or not mobile or not village:
                raise ValueError("Name, Mobile and Village are required")
            if not mobile.isdigit() or len(mobile) < 10:
                raise ValueError("Mobile must be 10+ digits")

            ctype_raw = (str(row.get("Type", "") or "domestic")).strip().lower()
            ctype = CustomerType.COMMERCIAL if ctype_raw.startswith("c") else CustomerType.DOMESTIC
            op_bal = Decimal(str(row.get("Opening_Balance", 0) or 0))
            op_bot = int(row.get("Opening_Bottles", 0) or 0)

            # skip if duplicate
            exists = db.scalar(select(Customer).where(
                Customer.mobile == mobile,
                Customer.village == village,
                Customer.is_deleted.is_(False),
            ))
            if exists:
                skipped += 1
                continue

            cust = Customer(
                name=name, mobile=mobile, village=village, city=city or village,
                customer_type=ctype, registration_date=date.today(),
                opening_balance=op_bal, opening_empty_bottles=op_bot,
                current_balance=op_bal, current_empty_bottles=op_bot,
                created_by_id=user_id,
            )
            db.add(cust)
            db.flush()
            if op_bot:
                db.add(EmptyBottleTransaction(
                    customer_id=cust.id,
                    transaction_type=EmptyBottleTxnType.OPENING,
                    quantity=op_bot, balance_after=op_bot,
                    notes="Opening balance (import)", created_by_id=user_id,
                ))
            imported += 1
        except Exception as e:
            errors.append(CustomerImportError(row=idx, error=str(e), data=row))

    write_audit(db, entity_type="customer", entity_id=None,
                action=AuditAction.IMPORT, user_id=user_id,
                changes={"imported": imported, "skipped": skipped, "errors": len(errors)})
    db.commit()
    return CustomerImportResult(imported=imported, skipped=skipped, errors=errors)


def export_customers_to_excel(db: Session) -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.title = "Customers"
    headers = [
        "ID", "Code", "Name", "Mobile", "Alt Mobile", "Village", "City",
        "District", "State", "Pincode", "Type", "Status",
        "Current Balance", "Empty Bottles", "Registration Date",
    ]
    ws.append(headers)
    for cust in db.scalars(select(Customer).where(Customer.is_deleted.is_(False)).order_by(Customer.name)):
        ws.append([
            cust.id, cust.customer_code, cust.name, cust.mobile, cust.alternate_mobile,
            cust.village, cust.city, cust.district, cust.state, cust.pincode,
            cust.customer_type.value, cust.status.value,
            float(cust.current_balance), cust.current_empty_bottles,
            cust.registration_date.isoformat() if cust.registration_date else "",
        ])
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue()
