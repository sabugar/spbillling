# Backend — API Reference

> **Authoritative map of the SPBilling backend.** If you are adding an endpoint, changing business logic, running a migration, or wiring the frontend — start here. Do not re-crawl `app/`.

**Stack:** FastAPI · SQLAlchemy 2.0 · PostgreSQL 16 (Docker) · Alembic · JWT · ReportLab · openpyxl
**URL prefix:** `/api` · **Port:** `8001` · **DB:** `postgresql+psycopg://postgres:postgres@localhost:5432/spgasbill`

---

## 1. Directory Map

```
backend/
├── app/
│   ├── config/        settings.py (env) · database.py (engine, SessionLocal, get_db)
│   ├── models/        9 files, 12 tables — ORM definitions only
│   ├── schemas/       Pydantic v2 request/response shapes per module
│   ├── services/      ALL business logic lives here (not in routers)
│   ├── routers/       Thin HTTP layer — delegates to services
│   ├── utils/         auth.py (JWT, hashing, guards), pagination.py, audit.py
│   └── main.py        FastAPI app, CORS, router registration, health endpoint
├── alembic/versions/  001_initial_schema.py
├── scripts/seed.py    Admin user + default settings + product catalog
├── requirements.txt   Pinned to Python 3.14 compatible versions
└── README.md          Setup & run commands
```

**Rule:** ORM queries ONLY in `services/`. Routers never touch the DB directly.

---

## 2. API Endpoints (all under `/api`)

### Auth · `routers/auth.py` → `services/auth_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| POST | `/api/auth/login` | Username/password → JWT | public |
| POST | `/api/auth/logout` | Client-side token drop (stateless) | any |
| GET  | `/api/auth/me` | Current user profile | any |

### Users · `routers/users.py` → `services/user_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET / POST | `/api/users` | List / create | admin |
| GET / PUT / DELETE | `/api/users/{id}` | Detail / update / deactivate | admin |

### Customers · `routers/customers.py` → `services/customer_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/customers` | Paginated list + filters | any |
| GET | `/api/customers/search?q=` | Autocomplete by name/mobile | any |
| GET | `/api/customers/{id}` | Detail | any |
| POST / PUT | `/api/customers[, /{id}]` | Create / update | staff+ |
| DELETE | `/api/customers/{id}` | Soft-delete | admin |
| POST | `/api/customers/import` | Bulk Excel import | staff+ |
| GET | `/api/customers/export/excel` | Export Excel | any |

### Products · `routers/products.py` → `services/product_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| CRUD | `/api/products/categories[, /{id}]` | Category master | admin |
| CRUD | `/api/products[, /{id}]` | Product master | admin |
| GET  | `/api/products/variants/list` | All variants paginated | any |
| CRUD | `/api/products/variants[, /{id}]` | Variant master (price, stock, GST, deposit) | admin |

### Bills · `routers/bills.py` → `services/billing_service.py` + `services/pdf_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/bills` | List (by customer / date / status) | any |
| POST / PUT | `/api/bills[, /{id}]` | Create / edit — runs GST, empty-bottle, stock, customer-balance updates | staff+ |
| GET | `/api/bills/{id}` | Detail with items | any |
| DELETE | `/api/bills/{id}` | Cancel — reverses balance/stock/empty | admin |
| GET | `/api/bills/{id}/pdf` | Single A4 PDF | any |
| GET | `/api/bills/print/batch?from=&to=&format=9up` | Batch 9-up or single | any |
| GET | `/api/bills/customer/{id}/ledger` | Full customer account ledger | any |

### Payments · `routers/payments.py` → `services/payment_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET / POST | `/api/payments` | List / record standalone receipt | staff+ |
| GET / PUT | `/api/payments/{id}` | Detail / update | staff+ |
| DELETE | `/api/payments/{id}` | Delete | admin |

### Cheques · `routers/cheques.py` → `services/payment_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/cheques` | Register (by status / date) | any |
| PUT | `/api/cheques/{id}/status` | pending → cleared / bounced / cancelled (cascades to payment + customer balance) | staff+ |

### Reports · `routers/reports.py` → `services/report_service.py`
| Method | Path | Purpose |
|---|---|---|
| GET | `/api/reports/dashboard` | Today's sales, cash, empty pending, dues |
| GET | `/api/reports/daily-sales` | Date-range sales |
| GET | `/api/reports/outstanding` | Customers with dues |
| GET | `/api/reports/empty-bottles` | Empty cylinder register |
| GET | `/api/reports/product-sales` | Variant-wise sold qty + revenue |
| GET | `/api/reports/cash-book` | Day-wise cash in |
| GET | `/api/reports/gst` | Monthly GST for filing |

### Settings · `routers/settings.py` → `services/setting_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/settings[, /{key}]` | List / fetch | any |
| PUT | `/api/settings/{key}` | Upsert | admin |
| DELETE | `/api/settings/{key}` | Delete | admin |

### Audit Logs · `routers/audit.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/audit-logs` | Mutation trail (by entity / user / date) | admin |

---

## 3. Services (business logic)

| File | Responsibility |
|---|---|
| `auth_service.py` | `authenticate()` — verify password, issue JWT |
| `user_service.py` | User CRUD, role & active checks |
| `customer_service.py` | CRUD · Excel import/export · `(mobile, village)` uniqueness |
| `product_service.py` | Category / product / variant CRUD · stock |
| `billing_service.py` | `_fy_prefix()`, `_next_bill_number()`, `create_bill()`, `cancel_bill()`, `customer_ledger()` — FY numbering, empty tracking, stock, customer-balance cascade |
| `payment_service.py` | Payments CRUD · cheque status transitions → payment + customer balance |
| `pdf_service.py` | `render_bill_pdf()` · `render_bills_9up_pdf()` (3×3 A4 grid) |
| `report_service.py` | All `/reports/*` aggregations |
| `setting_service.py` | Key/value settings upsert |

---

## 4. Models / Tables (12)

| Model file | Table(s) | Key constraints |
|---|---|---|
| `user.py` | `users` | UK(username), UK(email), IX(role, is_active) |
| `customer.py` | `customers` | **UK(mobile, village)**, UK(customer_code), IX(status, is_deleted), IX(mobile, is_deleted) |
| `product.py` | `product_categories`, `products`, `product_variants` | UK(category.name), UK(variant.sku_code), variants cascade-delete with product |
| `bill.py` | `bills`, `bill_items` | UK(bill_number), IX(customer_id, bill_date), IX(bill_date, status); items → bill CASCADE, → variant RESTRICT |
| `payment.py` | `payments` | UK(payment_number), IX(customer_id, payment_date) |
| `cheque.py` | `cheques` | IX(status, cheque_date); FKs to customer/bill/payment SET NULL |
| `empty_bottle.py` | `empty_bottle_transactions` | FK → customer CASCADE, IX(customer_id, created_at) |
| `audit.py` | `audit_logs` | IX(entity_type, entity_id, created_at), IX(user_id, created_at) |
| `setting.py` | `settings` | UK(key) |

---

## 5. Auth & Roles

- JWT HS256 via `python-jose`. Payload: `sub=user_id (str)`, `role`, `exp`. TTL 7 days (`ACCESS_TOKEN_EXPIRE_MINUTES=10080`).
- Password hashed via `passlib[bcrypt]` (bcrypt pinned `<5.0` — passlib compat).
- Roles: `admin` · `billing_staff` · `viewer`.
- Guards (in `app/utils/auth.py`): `get_current_user` (any), `require_staff` (admin+staff), `require_admin` (admin only). Apply via `Depends()` in the router signature.
- **Default admin (from `scripts/seed.py`):** `admin` / `admin123` — rotate before production.

---

## 6. Running

```bash
source venv/bin/activate
docker start spgasbill-postgres         # if not already up
alembic upgrade head                    # apply schema
python -m scripts.seed                  # idempotent — admin + catalog
uvicorn app.main:app --reload --port 8001
# Swagger: http://localhost:8001/docs
```

Login smoke test:
```bash
curl -X POST http://localhost:8001/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}'
```

---

## 7. Where to Look for What

| Task | File(s) |
|---|---|
| Add a new endpoint | `routers/<module>.py` + delegate to `services/` + register in `app/main.py` |
| Change business logic (any bill / payment / empty rule) | `services/<module>_service.py` — never in routers |
| Add a DB column / table | `models/<domain>.py` → `alembic revision --autogenerate -m "..."` → `alembic upgrade head` |
| Change bill number format | `billing_service._fy_prefix()` and `_next_bill_number()` |
| Change PDF layout (single or 9-up) | `services/pdf_service.py` |
| Change role permissions on a route | `Depends(require_admin / require_staff)` in the router |
| Tweak env / JWT TTL / bill code | `app/config/settings.py` + `.env` |
| Seed data (admin, categories, variants) | `scripts/seed.py` |
| Response shape | `schemas/common.py` — `APIResponse`, `PaginatedResponse` |
| Pagination helper | `app/utils/pagination.py` — `paginate(db, stmt, page, per_page, item_schema)` |
| Audit helper | `app/utils/audit.py` — `write_audit(...)`. Call from services on mutations. |

**Conventions:** success → `{"success": true, "message": "OK", "data": ...}` · error → `{"detail": "..."}` via `HTTPException` · store UTC, display IST in frontend · CORS currently `*` (tighten in `main.py` for prod).
