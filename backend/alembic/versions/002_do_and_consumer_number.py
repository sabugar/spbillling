"""add distributor_outlets + customer.do_id + customer.consumer_number

Revision ID: 002_do_consumer
Revises: 001_initial
Create Date: 2026-04-21

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "002_do_consumer"
down_revision: Union[str, None] = "001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---------- distributor_outlets ----------
    op.create_table(
        "distributor_outlets",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("code", sa.String(10), nullable=False),
        sa.Column("owner_name", sa.String(150), nullable=False),
        sa.Column("location", sa.String(150), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("code", name="uq_distributor_outlets_code"),
    )
    op.create_index("ix_distributor_outlets_code", "distributor_outlets", ["code"])
    op.create_index("ix_distributor_outlets_is_active", "distributor_outlets", ["is_active"])
    op.create_index("ix_distributor_outlets_is_deleted", "distributor_outlets", ["is_deleted"])
    op.create_index(
        "ix_distributor_outlets_active_deleted",
        "distributor_outlets", ["is_active", "is_deleted"],
    )

    # Seed bootstrap DO so existing customers (if any) can be back-filled.
    op.execute(
        "INSERT INTO distributor_outlets (code, owner_name, location, is_active, is_deleted) "
        "VALUES ('AA', 'Default Outlet', '-', true, false)"
    )

    # ---------- customers: add consumer_number + do_id ----------
    op.add_column(
        "customers",
        sa.Column("consumer_number", sa.String(32), nullable=True),
    )
    op.add_column(
        "customers",
        sa.Column("do_id", sa.Integer(), nullable=True),
    )

    # Back-fill: copy customer_code into consumer_number when present,
    # else 'TEMP-<id>'; bind every row to the bootstrap DO.
    op.execute(
        "UPDATE customers "
        "SET consumer_number = COALESCE(customer_code, 'TEMP-' || id), "
        "    do_id = (SELECT id FROM distributor_outlets ORDER BY id LIMIT 1) "
        "WHERE consumer_number IS NULL OR do_id IS NULL"
    )

    # Lock in NOT NULL, add FK + unique + indexes.
    op.alter_column("customers", "consumer_number", nullable=False)
    op.alter_column("customers", "do_id", nullable=False)

    op.create_foreign_key(
        "fk_customers_do_id_distributor_outlets",
        "customers", "distributor_outlets",
        ["do_id"], ["id"],
        ondelete="RESTRICT",
    )
    op.create_unique_constraint(
        "uq_customers_consumer_number", "customers", ["consumer_number"]
    )
    op.create_index("ix_customers_consumer_number", "customers", ["consumer_number"])
    op.create_index("ix_customers_do_id", "customers", ["do_id"])

    # Drop legacy customer_code column + its unique/index.
    op.drop_index("ix_customers_customer_code", table_name="customers")
    op.drop_constraint("uq_customers_code", "customers", type_="unique")
    op.drop_column("customers", "customer_code")


def downgrade() -> None:
    # Restore customer_code column (nullable, unique).
    op.add_column(
        "customers",
        sa.Column("customer_code", sa.String(32), nullable=True),
    )
    op.execute(
        "UPDATE customers SET customer_code = consumer_number "
        "WHERE consumer_number NOT LIKE 'TEMP-%'"
    )
    op.create_unique_constraint("uq_customers_code", "customers", ["customer_code"])
    op.create_index("ix_customers_customer_code", "customers", ["customer_code"])

    # Drop new additions on customers.
    op.drop_index("ix_customers_do_id", table_name="customers")
    op.drop_index("ix_customers_consumer_number", table_name="customers")
    op.drop_constraint("uq_customers_consumer_number", "customers", type_="unique")
    op.drop_constraint(
        "fk_customers_do_id_distributor_outlets", "customers", type_="foreignkey"
    )
    op.drop_column("customers", "do_id")
    op.drop_column("customers", "consumer_number")

    # Drop distributor_outlets.
    op.drop_index("ix_distributor_outlets_active_deleted", table_name="distributor_outlets")
    op.drop_index("ix_distributor_outlets_is_deleted", table_name="distributor_outlets")
    op.drop_index("ix_distributor_outlets_is_active", table_name="distributor_outlets")
    op.drop_index("ix_distributor_outlets_code", table_name="distributor_outlets")
    op.drop_table("distributor_outlets")
