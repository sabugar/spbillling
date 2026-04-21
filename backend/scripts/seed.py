"""Seed script: creates default admin user, sample categories/products, and default settings.

Run: python -m scripts.seed
"""
from datetime import date
from decimal import Decimal

from sqlalchemy import select

from app.config.database import SessionLocal
from app.models.product import Product, ProductCategory, ProductVariant
from app.models.setting import Setting
from app.models.user import User, UserRole
from app.utils.auth import hash_password


def seed_admin(db):
    if db.scalar(select(User).where(User.username == "admin")):
        print("✓ admin user exists")
        return
    admin = User(
        username="admin",
        email="admin@spbilling.local",
        password_hash=hash_password("admin123"),
        full_name="Administrator",
        role=UserRole.ADMIN,
        is_active=True,
    )
    db.add(admin)
    db.commit()
    print("✓ created admin user (username=admin, password=admin123)")


def seed_settings(db):
    defaults = {
        "business_name": "Gas Cylinder Distribution",
        "business_address": "Shop Address, City, Gujarat",
        "business_mobile": "9999999999",
        "business_gstin": "24XXXXXXXXXXZ5",
        "bill_tagline": "Thank you for your business!",
        "default_gst_rate": "5.0",
    }
    for k, v in defaults.items():
        if not db.scalar(select(Setting).where(Setting.key == k)):
            db.add(Setting(key=k, value=v))
    db.commit()
    print("✓ default settings seeded")


def seed_products(db):
    if db.scalar(select(ProductCategory)):
        print("✓ catalog already seeded")
        return
    cats = {
        "Cylinder": ProductCategory(name="Cylinder", display_order=1),
        "Regulator": ProductCategory(name="Regulator", display_order=2),
        "Stove": ProductCategory(name="Stove", display_order=3),
        "Accessory": ProductCategory(name="Accessory", display_order=4),
    }
    for c in cats.values():
        db.add(c)
    db.flush()

    cyl = Product(category_id=cats["Cylinder"].id, name="LPG Cylinder",
                  is_returnable=True, unit_of_measure="Pcs", hsn_code="27111900")
    reg = Product(category_id=cats["Regulator"].id, name="Gas Regulator",
                  is_returnable=False, unit_of_measure="Pcs")
    stove = Product(category_id=cats["Stove"].id, name="Gas Stove",
                    is_returnable=False, unit_of_measure="Pcs")
    db.add_all([cyl, reg, stove])
    db.flush()

    variants = [
        ProductVariant(product_id=cyl.id, name="Domestic 14.2kg",
                       unit_price=Decimal("1100"), deposit_amount=Decimal("2200"),
                       gst_rate=Decimal("5"), stock_quantity=50),
        ProductVariant(product_id=cyl.id, name="Commercial 15kg",
                       unit_price=Decimal("1800"), deposit_amount=Decimal("2500"),
                       gst_rate=Decimal("18"), stock_quantity=30),
        ProductVariant(product_id=cyl.id, name="Commercial 21kg",
                       unit_price=Decimal("2400"), deposit_amount=Decimal("3000"),
                       gst_rate=Decimal("18"), stock_quantity=20),
        ProductVariant(product_id=reg.id, name="Standard",
                       unit_price=Decimal("250"), gst_rate=Decimal("18"), stock_quantity=40),
        ProductVariant(product_id=stove.id, name="2-Burner",
                       unit_price=Decimal("1500"), gst_rate=Decimal("18"), stock_quantity=10),
    ]
    db.add_all(variants)
    db.commit()
    print("✓ product catalog seeded")


def main():
    db = SessionLocal()
    try:
        seed_admin(db)
        seed_settings(db)
        seed_products(db)
        print("\n✅ Seed complete.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
