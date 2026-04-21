"""initial schema

Revision ID: 001_initial
Revises:
Create Date: 2026-04-20

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---------- users ----------
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("username", sa.String(64), nullable=False),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(150), nullable=False),
        sa.Column("role", sa.String(32), nullable=False, server_default="billing_staff"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("last_login", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("username", name="uq_users_username"),
        sa.UniqueConstraint("email", name="uq_users_email"),
    )
    op.create_index("ix_users_username", "users", ["username"])
    op.create_index("ix_users_email", "users", ["email"])
    op.create_index("ix_users_role", "users", ["role"])
    op.create_index("ix_users_role_active", "users", ["role", "is_active"])

    # ---------- customers ----------
    op.create_table(
        "customers",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("customer_code", sa.String(32), nullable=True),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("mobile", sa.String(15), nullable=False),
        sa.Column("alternate_mobile", sa.String(15), nullable=True),
        sa.Column("village", sa.String(100), nullable=False),
        sa.Column("city", sa.String(100), nullable=False),
        sa.Column("district", sa.String(100), nullable=True),
        sa.Column("state", sa.String(100), nullable=True, server_default="Gujarat"),
        sa.Column("pincode", sa.String(10), nullable=True),
        sa.Column("full_address", sa.Text(), nullable=True),
        sa.Column("customer_type", sa.String(16), nullable=False, server_default="domestic"),
        sa.Column("aadhaar_number", sa.String(20), nullable=True),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("date_of_birth", sa.Date(), nullable=True),
        sa.Column("registration_date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="active"),
        sa.Column("opening_balance", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("opening_empty_bottles", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("current_balance", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("current_empty_bottles", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_by_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("customer_code", name="uq_customers_code"),
        sa.UniqueConstraint("mobile", "village", name="uq_customer_mobile_village"),
    )
    op.create_index("ix_customers_customer_code", "customers", ["customer_code"])
    op.create_index("ix_customers_mobile", "customers", ["mobile"])
    op.create_index("ix_customers_village", "customers", ["village"])
    op.create_index("ix_customers_city", "customers", ["city"])
    op.create_index("ix_customers_customer_type", "customers", ["customer_type"])
    op.create_index("ix_customers_status", "customers", ["status"])
    op.create_index("ix_customers_created_by_id", "customers", ["created_by_id"])
    op.create_index("ix_customers_name_village", "customers", ["name", "village"])
    op.create_index("ix_customers_status_deleted", "customers", ["status", "is_deleted"])
    op.create_index("ix_customers_mobile_deleted", "customers", ["mobile", "is_deleted"])

    # ---------- product_categories ----------
    op.create_table(
        "product_categories",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("display_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("name", name="uq_product_categories_name"),
    )
    op.create_index("ix_product_categories_name", "product_categories", ["name"])

    # ---------- products ----------
    op.create_table(
        "products",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("category_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("is_returnable", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("hsn_code", sa.String(20), nullable=True),
        sa.Column("unit_of_measure", sa.String(20), nullable=False, server_default="Pcs"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["category_id"], ["product_categories.id"], ondelete="RESTRICT"),
    )
    op.create_index("ix_products_category_id", "products", ["category_id"])
    op.create_index("ix_products_name", "products", ["name"])
    op.create_index("ix_products_is_active", "products", ["is_active"])
    op.create_index("ix_products_category_active", "products", ["category_id", "is_active"])

    # ---------- product_variants ----------
    op.create_table(
        "product_variants",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("product_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("sku_code", sa.String(50), nullable=True),
        sa.Column("unit_price", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("cost_price", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("deposit_amount", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("gst_rate", sa.Numeric(5, 2), nullable=False, server_default="0"),
        sa.Column("stock_quantity", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["product_id"], ["products.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("sku_code", name="uq_product_variants_sku"),
    )
    op.create_index("ix_product_variants_product_id", "product_variants", ["product_id"])
    op.create_index("ix_product_variants_name", "product_variants", ["name"])
    op.create_index("ix_product_variants_sku_code", "product_variants", ["sku_code"])
    op.create_index("ix_variants_product_active", "product_variants", ["product_id", "is_active"])

    # ---------- bills ----------
    op.create_table(
        "bills",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("bill_number", sa.String(40), nullable=False),
        sa.Column("bill_date", sa.Date(), nullable=False),
        sa.Column("customer_id", sa.Integer(), nullable=False),
        sa.Column("subtotal", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("discount", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("gst_amount", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("total_amount", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("amount_paid", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("balance_due", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("payment_mode", sa.String(16), nullable=False, server_default="cash"),
        sa.Column("cheque_details", sa.JSON(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("status", sa.String(16), nullable=False, server_default="confirmed"),
        sa.Column("created_by_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["customer_id"], ["customers.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("bill_number", name="uq_bills_number"),
    )
    op.create_index("ix_bills_bill_number", "bills", ["bill_number"])
    op.create_index("ix_bills_bill_date", "bills", ["bill_date"])
    op.create_index("ix_bills_customer_id", "bills", ["customer_id"])
    op.create_index("ix_bills_payment_mode", "bills", ["payment_mode"])
    op.create_index("ix_bills_status", "bills", ["status"])
    op.create_index("ix_bills_created_by_id", "bills", ["created_by_id"])
    op.create_index("ix_bills_customer_date", "bills", ["customer_id", "bill_date"])
    op.create_index("ix_bills_date_status", "bills", ["bill_date", "status"])

    # ---------- bill_items ----------
    op.create_table(
        "bill_items",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("bill_id", sa.Integer(), nullable=False),
        sa.Column("product_variant_id", sa.Integer(), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("rate", sa.Numeric(12, 2), nullable=False),
        sa.Column("empty_returned", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("gst_rate", sa.Numeric(5, 2), nullable=False, server_default="0"),
        sa.Column("gst_amount", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("line_total", sa.Numeric(12, 2), nullable=False),
        sa.ForeignKeyConstraint(["bill_id"], ["bills.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["product_variant_id"], ["product_variants.id"], ondelete="RESTRICT"),
    )
    op.create_index("ix_bill_items_bill_id", "bill_items", ["bill_id"])
    op.create_index("ix_bill_items_product_variant_id", "bill_items", ["product_variant_id"])

    # ---------- payments ----------
    op.create_table(
        "payments",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("payment_number", sa.String(40), nullable=False),
        sa.Column("payment_date", sa.Date(), nullable=False),
        sa.Column("customer_id", sa.Integer(), nullable=False),
        sa.Column("reference_bill_id", sa.Integer(), nullable=True),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("payment_mode", sa.String(16), nullable=False, server_default="cash"),
        sa.Column("cheque_details", sa.JSON(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("status", sa.String(16), nullable=False, server_default="cleared"),
        sa.Column("created_by_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["customer_id"], ["customers.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["reference_bill_id"], ["bills.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("payment_number", name="uq_payments_number"),
    )
    op.create_index("ix_payments_payment_number", "payments", ["payment_number"])
    op.create_index("ix_payments_payment_date", "payments", ["payment_date"])
    op.create_index("ix_payments_customer_id", "payments", ["customer_id"])
    op.create_index("ix_payments_reference_bill_id", "payments", ["reference_bill_id"])
    op.create_index("ix_payments_payment_mode", "payments", ["payment_mode"])
    op.create_index("ix_payments_status", "payments", ["status"])
    op.create_index("ix_payments_customer_date", "payments", ["customer_id", "payment_date"])

    # ---------- cheques ----------
    op.create_table(
        "cheques",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("cheque_number", sa.String(32), nullable=False),
        sa.Column("bank_name", sa.String(100), nullable=False),
        sa.Column("branch_name", sa.String(100), nullable=True),
        sa.Column("cheque_date", sa.Date(), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("customer_id", sa.Integer(), nullable=True),
        sa.Column("bill_id", sa.Integer(), nullable=True),
        sa.Column("payment_id", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(16), nullable=False, server_default="pending"),
        sa.Column("cleared_date", sa.Date(), nullable=True),
        sa.Column("bounce_reason", sa.Text(), nullable=True),
        sa.Column("created_by_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["customer_id"], ["customers.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["bill_id"], ["bills.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["payment_id"], ["payments.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_cheques_cheque_number", "cheques", ["cheque_number"])
    op.create_index("ix_cheques_cheque_date", "cheques", ["cheque_date"])
    op.create_index("ix_cheques_customer_id", "cheques", ["customer_id"])
    op.create_index("ix_cheques_bill_id", "cheques", ["bill_id"])
    op.create_index("ix_cheques_payment_id", "cheques", ["payment_id"])
    op.create_index("ix_cheques_status", "cheques", ["status"])
    op.create_index("ix_cheques_status_date", "cheques", ["status", "cheque_date"])

    # ---------- empty_bottle_transactions ----------
    op.create_table(
        "empty_bottle_transactions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("customer_id", sa.Integer(), nullable=False),
        sa.Column("bill_id", sa.Integer(), nullable=True),
        sa.Column("transaction_type", sa.String(16), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("balance_after", sa.Integer(), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_by_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["customer_id"], ["customers.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["bill_id"], ["bills.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_empty_bottle_customer_id", "empty_bottle_transactions", ["customer_id"])
    op.create_index("ix_empty_bottle_bill_id", "empty_bottle_transactions", ["bill_id"])
    op.create_index("ix_empty_bottle_transaction_type", "empty_bottle_transactions", ["transaction_type"])
    op.create_index(
        "ix_empty_bottle_customer_created",
        "empty_bottle_transactions",
        ["customer_id", "created_at"],
    )

    # ---------- audit_logs ----------
    op.create_table(
        "audit_logs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("entity_type", sa.String(50), nullable=False),
        sa.Column("entity_id", sa.Integer(), nullable=True),
        sa.Column("action", sa.String(16), nullable=False),
        sa.Column("changes", sa.JSON(), nullable=True),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("ip_address", sa.String(45), nullable=True),
        sa.Column("user_agent", sa.String(255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_audit_logs_entity_type", "audit_logs", ["entity_type"])
    op.create_index("ix_audit_logs_entity_id", "audit_logs", ["entity_id"])
    op.create_index("ix_audit_logs_action", "audit_logs", ["action"])
    op.create_index("ix_audit_logs_user_id", "audit_logs", ["user_id"])
    op.create_index("ix_audit_entity", "audit_logs", ["entity_type", "entity_id", "created_at"])
    op.create_index("ix_audit_user_time", "audit_logs", ["user_id", "created_at"])

    # ---------- settings ----------
    op.create_table(
        "settings",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("key", sa.String(100), nullable=False),
        sa.Column("value", sa.Text(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("updated_by_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["updated_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("key", name="uq_settings_key"),
    )
    op.create_index("ix_settings_key", "settings", ["key"])


def downgrade() -> None:
    op.drop_table("settings")
    op.drop_table("audit_logs")
    op.drop_table("empty_bottle_transactions")
    op.drop_table("cheques")
    op.drop_table("payments")
    op.drop_table("bill_items")
    op.drop_table("bills")
    op.drop_table("product_variants")
    op.drop_table("products")
    op.drop_table("product_categories")
    op.drop_table("customers")
    op.drop_table("users")
