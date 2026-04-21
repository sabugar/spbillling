import math
from typing import Any

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

from app.schemas.common import PaginatedResponse, PaginationMeta


def paginate(
    db: Session,
    stmt: Select,
    page: int = 1,
    per_page: int = 20,
    item_schema: Any = None,
) -> PaginatedResponse:
    count_stmt = select(func.count()).select_from(stmt.order_by(None).subquery())
    total = db.scalar(count_stmt) or 0
    rows = db.execute(stmt.offset((page - 1) * per_page).limit(per_page)).scalars().all()
    items = [item_schema.model_validate(r) for r in rows] if item_schema else list(rows)
    last_page = max(1, math.ceil(total / per_page))
    return PaginatedResponse(
        data=items,
        meta=PaginationMeta(total=total, page=page, per_page=per_page, last_page=last_page),
    )
