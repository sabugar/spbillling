# SPBilling Backend — FastAPI

Gas Cylinder Distribution Management System — REST API backend.

- **Stack:** FastAPI · SQLAlchemy 2.0 · PostgreSQL 16 · Alembic · JWT auth
- **DB container:** `spgasbill-postgres` (see `/Users/apple/Desktop/spgas/spbilling/claude.md §2.3`)

## 1. Setup

```bash
cd /Users/apple/Desktop/spgas/spbilling/backend

# Virtual env
python3 -m venv venv
source venv/bin/activate

# Dependencies
pip install -r requirements.txt

# Environment
cp .env.example .env
# Default connects to the spgasbill-postgres Docker container

# Ensure postgres container is running
docker start spgasbill-postgres

# Run migrations
alembic upgrade head

# Seed admin + catalog
python -m scripts.seed
```

## 2. Run

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
```

- Swagger: http://localhost:8001/docs
- ReDoc: http://localhost:8001/redoc
- Health: http://localhost:8001/health

> Port **8001** to avoid conflict with GasTrack Pro backend on 8000.

## 3. Login

```bash
curl -X POST http://localhost:8001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

Response contains `access_token`. Use as `Authorization: Bearer <token>` on subsequent requests.

## 4. API Modules

| Module | Prefix | Notes |
|--------|--------|-------|
| Auth | `/api/auth` | login, logout, me |
| Users | `/api/users` | admin only |
| Customers | `/api/customers` | CRUD, search, import/export Excel, ledger |
| Products | `/api/products` | categories, products, variants |
| Bills | `/api/bills` | create/edit/cancel, PDF, 9-up A4 batch print |
| Payments | `/api/payments` | standalone receipts |
| Cheques | `/api/cheques` | register + status updates |
| Reports | `/api/reports` | daily sales, outstanding, empty, GST, cash book, dashboard |
| Settings | `/api/settings` | business profile, GST, bill numbering |
| Audit Logs | `/api/audit-logs` | admin-only activity trail |

## 5. Database Schema

12 tables with proper PK/FK/indexes:

- `users` — app users with roles (admin / billing_staff / viewer)
- `customers` — with `uq(mobile, village)` enforcing customer identity
- `product_categories`, `products`, `product_variants`
- `bills`, `bill_items` (FK cascade on delete)
- `payments` — standalone receipts, may reference a bill
- `cheques` — register with status transitions
- `empty_bottle_transactions` — audit log for cylinder returns
- `audit_logs` — all mutations tracked with user + changes JSON
- `settings` — key-value business configuration

## 6. Migrations

```bash
# New migration
alembic revision --autogenerate -m "add column X"

# Apply
alembic upgrade head

# Rollback one
alembic downgrade -1
```

## 7. Business Rules (enforced in services)

- Customer identified by **(mobile, village)** — unique pair.
- Bill total = `subtotal + GST − discount`. Balance = `total − paid`.
- Customer balance updated on every bill/payment; reversed on cancel.
- Empty bottle count: `+quantity − empty_returned` per returnable item; reversed on cancel.
- Stock decrements on bill creation; restored on cancel.
- Bill number format: `BILL/{FY}/NNNN` (Indian fiscal year, Apr-Mar).
- Cheque payment → `payments.status = pending` until cheque cleared.
- Soft delete for customers (`is_deleted` flag); no hard delete.
- All mutations write to `audit_logs`.

## 8. Auth & Roles

- `admin` — full access (users, settings, cancels, deletes)
- `billing_staff` — create/edit bills, customers, payments
- `viewer` — read-only
