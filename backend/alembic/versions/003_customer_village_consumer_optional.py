"""make customer.village and customer.consumer_number optional

Revision ID: 003_village_optional
Revises: 002_do_consumer
Create Date: 2026-04-21

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "003_village_optional"
down_revision: Union[str, None] = "002_do_consumer"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop village-based uniqueness + composite index; village is going optional.
    op.drop_constraint("uq_customer_mobile_village", "customers", type_="unique")
    op.drop_index("ix_customers_name_village", table_name="customers")

    # Relax NOT NULL on village and consumer_number.
    op.alter_column("customers", "village", existing_type=sa.String(100), nullable=True)
    op.alter_column(
        "customers", "consumer_number", existing_type=sa.String(32), nullable=True
    )


def downgrade() -> None:
    # Fill NULLs before restoring NOT NULL.
    op.execute("UPDATE customers SET village = '—' WHERE village IS NULL")
    op.execute(
        "UPDATE customers SET consumer_number = 'TEMP-' || id WHERE consumer_number IS NULL"
    )

    op.alter_column(
        "customers", "consumer_number", existing_type=sa.String(32), nullable=False
    )
    op.alter_column("customers", "village", existing_type=sa.String(100), nullable=False)

    op.create_index("ix_customers_name_village", "customers", ["name", "village"])
    op.create_unique_constraint(
        "uq_customer_mobile_village", "customers", ["mobile", "village"]
    )
