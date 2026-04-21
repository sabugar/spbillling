from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.audit import AuditAction
from app.models.product import Product, ProductCategory, ProductVariant
from app.schemas.product import (
    CategoryCreate, CategoryUpdate, ProductCreate, ProductUpdate, VariantCreate, VariantUpdate,
)
from app.utils.audit import write_audit


# ---------- Categories ----------
def list_categories(db: Session, include_inactive: bool = False):
    stmt = select(ProductCategory).order_by(ProductCategory.display_order, ProductCategory.name)
    if not include_inactive:
        stmt = stmt.where(ProductCategory.is_active.is_(True))
    return list(db.scalars(stmt).all())


def create_category(db: Session, payload: CategoryCreate, user_id: int) -> ProductCategory:
    if db.scalar(select(ProductCategory).where(ProductCategory.name == payload.name)):
        raise HTTPException(status_code=400, detail="Category name already exists")
    cat = ProductCategory(**payload.model_dump())
    db.add(cat)
    db.flush()
    write_audit(db, entity_type="category", entity_id=cat.id,
                action=AuditAction.CREATE, user_id=user_id, changes=payload.model_dump())
    db.commit()
    db.refresh(cat)
    return cat


def update_category(db: Session, cat_id: int, payload: CategoryUpdate, user_id: int) -> ProductCategory:
    cat = db.get(ProductCategory, cat_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(cat, k, v)
    write_audit(db, entity_type="category", entity_id=cat.id,
                action=AuditAction.UPDATE, user_id=user_id)
    db.commit()
    db.refresh(cat)
    return cat


def delete_category(db: Session, cat_id: int, user_id: int) -> None:
    cat = db.get(ProductCategory, cat_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    if db.scalar(select(Product).where(Product.category_id == cat_id).limit(1)):
        raise HTTPException(status_code=400, detail="Category has products; cannot delete")
    db.delete(cat)
    write_audit(db, entity_type="category", entity_id=cat_id,
                action=AuditAction.DELETE, user_id=user_id)
    db.commit()


# ---------- Products ----------
def list_products(db: Session, category_id: int | None = None, include_inactive: bool = False):
    stmt = select(Product).order_by(Product.name)
    if category_id:
        stmt = stmt.where(Product.category_id == category_id)
    if not include_inactive:
        stmt = stmt.where(Product.is_active.is_(True))
    return stmt


def get_product(db: Session, product_id: int) -> Product:
    p = db.get(Product, product_id)
    if not p:
        raise HTTPException(status_code=404, detail="Product not found")
    return p


def create_product(db: Session, payload: ProductCreate, user_id: int) -> Product:
    if not db.get(ProductCategory, payload.category_id):
        raise HTTPException(status_code=400, detail="Invalid category_id")
    p = Product(**payload.model_dump())
    db.add(p)
    db.flush()
    write_audit(db, entity_type="product", entity_id=p.id,
                action=AuditAction.CREATE, user_id=user_id, changes=payload.model_dump())
    db.commit()
    db.refresh(p)
    return p


def update_product(db: Session, product_id: int, payload: ProductUpdate, user_id: int) -> Product:
    p = get_product(db, product_id)
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(p, k, v)
    write_audit(db, entity_type="product", entity_id=p.id,
                action=AuditAction.UPDATE, user_id=user_id)
    db.commit()
    db.refresh(p)
    return p


def delete_product(db: Session, product_id: int, user_id: int) -> None:
    p = get_product(db, product_id)
    p.is_active = False  # soft-delete via flag (variants still referenced in old bills)
    write_audit(db, entity_type="product", entity_id=p.id,
                action=AuditAction.DELETE, user_id=user_id)
    db.commit()


# ---------- Variants ----------
def list_variants(db: Session, product_id: int | None = None, include_inactive: bool = False):
    stmt = select(ProductVariant).order_by(ProductVariant.name)
    if product_id:
        stmt = stmt.where(ProductVariant.product_id == product_id)
    if not include_inactive:
        stmt = stmt.where(ProductVariant.is_active.is_(True))
    return stmt


def get_variant(db: Session, variant_id: int) -> ProductVariant:
    v = db.get(ProductVariant, variant_id)
    if not v:
        raise HTTPException(status_code=404, detail="Variant not found")
    return v


def create_variant(db: Session, payload: VariantCreate, user_id: int) -> ProductVariant:
    if not db.get(Product, payload.product_id):
        raise HTTPException(status_code=400, detail="Invalid product_id")
    if payload.sku_code and db.scalar(
        select(ProductVariant).where(ProductVariant.sku_code == payload.sku_code)
    ):
        raise HTTPException(status_code=400, detail="SKU code already exists")
    v = ProductVariant(**payload.model_dump())
    db.add(v)
    db.flush()
    write_audit(db, entity_type="variant", entity_id=v.id,
                action=AuditAction.CREATE, user_id=user_id)
    db.commit()
    db.refresh(v)
    return v


def update_variant(db: Session, variant_id: int, payload: VariantUpdate, user_id: int) -> ProductVariant:
    v = get_variant(db, variant_id)
    for k, val in payload.model_dump(exclude_unset=True).items():
        setattr(v, k, val)
    write_audit(db, entity_type="variant", entity_id=v.id,
                action=AuditAction.UPDATE, user_id=user_id)
    db.commit()
    db.refresh(v)
    return v


def delete_variant(db: Session, variant_id: int, user_id: int) -> None:
    v = get_variant(db, variant_id)
    v.is_active = False
    write_audit(db, entity_type="variant", entity_id=v.id,
                action=AuditAction.DELETE, user_id=user_id)
    db.commit()
