from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.user import User
from app.schemas.common import APIResponse, PaginatedResponse
from app.schemas.product import (
    CategoryCreate, CategoryOut, CategoryUpdate,
    ProductCreate, ProductOut, ProductUpdate, ProductWithVariants,
    VariantCreate, VariantOut, VariantUpdate,
)
from app.services import product_service
from app.utils.auth import get_current_user, require_admin
from app.utils.pagination import paginate

router = APIRouter(prefix="/products", tags=["Products"])


# ---------- Categories ----------
@router.get("/categories", response_model=APIResponse[list[CategoryOut]])
def list_categories(
    include_inactive: bool = False,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    rows = product_service.list_categories(db, include_inactive)
    return APIResponse(data=[CategoryOut.model_validate(r) for r in rows])


@router.post("/categories", response_model=APIResponse[CategoryOut])
def create_category(payload: CategoryCreate, db: Session = Depends(get_db),
                    user: User = Depends(require_admin)):
    cat = product_service.create_category(db, payload, user.id)
    return APIResponse(data=CategoryOut.model_validate(cat), message="Category created")


@router.put("/categories/{cat_id}", response_model=APIResponse[CategoryOut])
def update_category(cat_id: int, payload: CategoryUpdate,
                    db: Session = Depends(get_db), user: User = Depends(require_admin)):
    cat = product_service.update_category(db, cat_id, payload, user.id)
    return APIResponse(data=CategoryOut.model_validate(cat), message="Category updated")


@router.delete("/categories/{cat_id}", response_model=APIResponse)
def delete_category(cat_id: int, db: Session = Depends(get_db),
                    user: User = Depends(require_admin)):
    product_service.delete_category(db, cat_id, user.id)
    return APIResponse(message="Category deleted")


# ---------- Products ----------
@router.get("", response_model=PaginatedResponse[ProductOut])
def list_products(
    category_id: Optional[int] = None,
    include_inactive: bool = False,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    stmt = product_service.list_products(db, category_id, include_inactive)
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=ProductOut)


@router.get("/{product_id}", response_model=APIResponse[ProductWithVariants])
def get_product(product_id: int, db: Session = Depends(get_db),
                _user: User = Depends(get_current_user)):
    p = product_service.get_product(db, product_id)
    data = ProductWithVariants.model_validate(p)
    data.variants = [VariantOut.model_validate(v) for v in p.variants]
    return APIResponse(data=data)


@router.post("", response_model=APIResponse[ProductOut])
def create_product(payload: ProductCreate, db: Session = Depends(get_db),
                   user: User = Depends(require_admin)):
    p = product_service.create_product(db, payload, user.id)
    return APIResponse(data=ProductOut.model_validate(p), message="Product created")


@router.put("/{product_id}", response_model=APIResponse[ProductOut])
def update_product(product_id: int, payload: ProductUpdate,
                   db: Session = Depends(get_db), user: User = Depends(require_admin)):
    p = product_service.update_product(db, product_id, payload, user.id)
    return APIResponse(data=ProductOut.model_validate(p), message="Product updated")


@router.delete("/{product_id}", response_model=APIResponse)
def delete_product(product_id: int, db: Session = Depends(get_db),
                   user: User = Depends(require_admin)):
    product_service.delete_product(db, product_id, user.id)
    return APIResponse(message="Product deactivated")


# ---------- Variants ----------
@router.get("/variants/list", response_model=PaginatedResponse[VariantOut])
def list_variants(
    product_id: Optional[int] = None,
    include_inactive: bool = False,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    stmt = product_service.list_variants(db, product_id, include_inactive)
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=VariantOut)


@router.post("/variants", response_model=APIResponse[VariantOut])
def create_variant(payload: VariantCreate, db: Session = Depends(get_db),
                   user: User = Depends(require_admin)):
    v = product_service.create_variant(db, payload, user.id)
    return APIResponse(data=VariantOut.model_validate(v), message="Variant created")


@router.put("/variants/{variant_id}", response_model=APIResponse[VariantOut])
def update_variant(variant_id: int, payload: VariantUpdate,
                   db: Session = Depends(get_db), user: User = Depends(require_admin)):
    v = product_service.update_variant(db, variant_id, payload, user.id)
    return APIResponse(data=VariantOut.model_validate(v), message="Variant updated")


@router.delete("/variants/{variant_id}", response_model=APIResponse)
def delete_variant(variant_id: int, db: Session = Depends(get_db),
                   user: User = Depends(require_admin)):
    product_service.delete_variant(db, variant_id, user.id)
    return APIResponse(message="Variant deactivated")
