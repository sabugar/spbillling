# Gas Cylinder Distribution Management System
## Complete Technical & Commercial Documentation

---

## ⚠️ Design & UI Work — Mandatory Reference

**Any work that touches the UI — screens, components, colors, spacing, typography, icons, layouts, print templates — MUST first consult the design system guide:**

➡️ **[`Designing/CLAUDE.md`](./Designing/CLAUDE.md)** — UI kit, design tokens, component dictionary, do's & don'ts.

Supporting artifacts in the same folder:
- `Designing/ui-kit.html` — live component dictionary (open in browser).
- `Designing/spgas/styles.css` — full design system (CSS variables + every component class).
- `Designing/spgas/src/` — React reference implementation (shell, primitives, 9 screens).

**Rule:** Do not invent new colors, spacings, components, or patterns. If it isn't in the design system, stop and ask. Consistency is a feature.

---

## ⚠️ Backend / API Work — Mandatory Reference

**Any work on endpoints, DB schema, business logic, migrations, auth, PDF/Excel, or seed data — MUST first consult:**

➡️ **[`backend/CLAUDE.md`](./backend/CLAUDE.md)** — full API map (every endpoint → router → service → role), model/constraint index, auth guards, run & migration commands, "where to look for what" lookup.

Backend lives entirely under `backend/`. Running stack: FastAPI + SQLAlchemy 2.0 + Postgres 16 (Docker container `spgasbill-postgres`). URL prefix `/api`, port `8001`. Default admin: `admin / admin123`. Swagger UI at `http://localhost:8001/docs`.

---

## 1. Project Overview

### 1.1 Purpose
A comprehensive business management application for gas cylinder distribution businesses that handles customer management, product catalog, sales transactions, bottle/cylinder tracking, payment management, and bill generation.

### 1.2 Target Platforms
- **Primary:** Windows Desktop Application
- **Future Extensions:** Web Application, Android App, iOS App
- **Approach:** Single codebase (cross-platform) for easier maintenance

### 1.3 Business Domain
- Gas cylinder distribution (Commercial & Domestic)
- Multiple product variants (Cylinders, Regulators, Stoves, Accessories)
- Customer-wise bottle/empty cylinder tracking
- Cash/Cheque/Online payment management

---

## 2. Recommended Technology Stack

### 2.1 Frontend Framework — **Flutter (Recommended)**

**Why Flutter:**
- Single codebase for Windows, Web, Android, iOS, macOS, Linux
- Native performance on all platforms
- Excellent UI capabilities with Material Design 3
- Strong community and Google backing
- Offline-first capabilities
- Easy to hire developers

**Alternative Options Considered:**
| Framework | Pros | Cons |
|-----------|------|------|
| **Flutter** ✅ | One codebase, native performance, beautiful UI | Larger app size |
| .NET MAUI | Great for Windows, C# | Weaker web support |
| Electron + React | Web-friendly | Heavy on resources |
| React Native | Popular | Desktop support limited |

### 2.2 Backend
- **Language:** Dart (if using Flutter for full-stack) OR Node.js with Express OR .NET Core
- **Recommended:** **Node.js + Express + TypeScript** for backend API
- **API Style:** RESTful API with JSON + JWT authentication

### 2.3 Database
- **Primary:** PostgreSQL 16 (reliable, open-source, scalable)
- **Local Cache (Offline Support):** SQLite (via `sqflite` package in Flutter)
- **Sync Strategy:** Local-first with background sync to cloud when online

#### Local Dev — Docker Container (running)
| Parameter | Value |
|-----------|-------|
| Container name | `spgasbill-postgres` |
| Image | `postgres:16-alpine` |
| Host | `localhost` |
| Port | `5432` |
| Database | `spgasbill` |
| Username | `postgres` |
| Password | `postgres` _(dev-only — rotate before production)_ |
| Volume | `spgasbill-pgdata` (persistent) |
| Restart policy | `unless-stopped` |

**Connection string (dev):**
```
postgresql://postgres:postgres@localhost:5432/spgasbill
```

**Useful commands:**
```bash
# Start / stop
docker start spgasbill-postgres
docker stop spgasbill-postgres

# Connect via psql
docker exec -it spgasbill-postgres psql -U postgres -d spgasbill

# Check status
docker ps --filter name=spgasbill-postgres
```

### 2.4 Additional Libraries/Tools
- **State Management:** Riverpod or Bloc (Flutter)
- **Bill/PDF Generation:** `pdf` and `printing` Flutter packages
- **Excel Import/Export:** `excel` and `csv` packages
- **Charts/Reports:** `fl_chart` package
- **Authentication:** JWT + secure storage
- **Barcode/QR:** `mobile_scanner` (for future cylinder tracking)

### 2.5 Deployment
- **Windows:** MSIX installer or `.exe` via Inno Setup
- **Web:** Deploy on VPS (DigitalOcean/AWS) with Nginx
- **Mobile:** Google Play Store & Apple App Store
- **Backend:** Docker container on VPS

---

## 3. Functional Requirements

### 3.1 Module 1 — Customer Management

#### 3.1.1 Features
| Feature | Description |
|---------|-------------|
| Add Customer | Manually add a new customer with all details |
| Edit Customer | Modify existing customer information |
| Delete Customer | Soft delete (mark as deleted, keep in DB for history) |
| Import Customers | Bulk import from Excel/CSV sheet (format provided by owner) |
| Export Customers | Export to Excel/CSV |
| Active/Inactive | Toggle customer status without deleting |
| Search Customers | Search by Name, Mobile Number, Village/City/Area |
| View History | See complete transaction history of a customer |

#### 3.1.2 Customer Data Fields
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Customer ID | Auto | Yes | Auto-generated unique ID |
| Customer Name | Text | Yes | Full name |
| Mobile Number | Text (10 digits) | Yes | Primary identifier, indexed |
| Alternate Mobile | Text | No | Secondary contact |
| Village / Area | Text | Yes | Used for disambiguation |
| City | Text | Yes | |
| District | Text | No | |
| State | Text | No | Default to Gujarat or user-configurable |
| Pincode | Text (6 digits) | No | |
| Full Address | Text | No | Multi-line |
| Customer Type | Enum | Yes | Domestic / Commercial |
| Aadhaar Number | Text | No | Optional, encrypted |
| Email | Text | No | Optional |
| Date of Birth | Date | No | Optional |
| Registration Date | Date | Auto | Auto-captured |
| Status | Enum | Yes | Active / Inactive |
| Opening Balance | Decimal | No | Initial dues if any |
| Opening Empty Bottles | Integer | No | Initial empty cylinders owed |
| Notes | Text | No | Free-text notes |
| Created At | Timestamp | Auto | |
| Updated At | Timestamp | Auto | |

#### 3.1.3 Customer Identification Logic (Critical)
**When searching customer during billing:**
1. **By Mobile Number** — Primary method, exact match
2. **By Name** — Show suggestions with Name + Village/Area in dropdown
   - Example: "Manoj Patel" returns:
     - Manoj Patel — Ranasan
     - Manoj Patel — Gambhoi
     - Manoj Patel — Khedbrahma
3. **Autocomplete** — Start typing, show suggestions
4. **Mandatory:** Village/Area must always display alongside name

#### 3.1.4 Excel Import Format (Placeholder — to be provided by owner)
```
Columns: Name | Mobile | Village | City | Type | Opening_Balance | Opening_Bottles
```
Validation rules:
- Mobile must be 10 digits, unique
- Name and Village mandatory
- Invalid rows shown in error report after import

---

### 3.2 Module 2 — Product Management

#### 3.2.1 Features
- Add, Edit, Delete, Active/Inactive products
- Manage product **variants** (size, category)
- Set pricing per variant
- Manage stock levels (optional — Phase 2)
- Product categories

#### 3.2.2 Product Structure
```
Category (e.g., Cylinder, Regulator, Stove, Accessories)
  └── Product (e.g., Cylinder)
        └── Variant (e.g., Commercial 15kg, Commercial 21kg, Domestic 15kg)
```

#### 3.2.3 Product Data Fields
| Field | Type | Notes |
|-------|------|-------|
| Product ID | Auto | Unique ID |
| Category | Enum | Cylinder, Regulator, Stove, Accessory, Other |
| Product Name | Text | e.g., "LPG Cylinder" |
| Variant Name | Text | e.g., "Commercial 15kg" |
| SKU Code | Text | Optional barcode/SKU |
| Unit Price | Decimal | Selling price |
| Cost Price | Decimal | For profit calculation |
| Deposit Amount | Decimal | For cylinders (refundable deposit) |
| Is Returnable | Boolean | True for cylinders (empty return required) |
| HSN Code | Text | For GST compliance |
| GST Rate | Decimal | Applicable GST % |
| Unit of Measure | Text | "Pcs", "Kg", etc. |
| Stock Quantity | Integer | Current stock (optional) |
| Status | Enum | Active / Inactive |

#### 3.2.4 Example Product Catalog
| Category | Product | Variant | Price | Deposit | Returnable |
|----------|---------|---------|-------|---------|------------|
| Cylinder | LPG Cylinder | Domestic 14.2kg | ₹1100 | ₹2200 | Yes |
| Cylinder | LPG Cylinder | Commercial 15kg | ₹1800 | ₹2500 | Yes |
| Cylinder | LPG Cylinder | Commercial 21kg | ₹2400 | ₹3000 | Yes |
| Regulator | Gas Regulator | Standard | ₹250 | — | No |
| Stove | Gas Stove | 2-Burner | ₹1500 | — | No |

---

### 3.3 Module 3 — Transaction / Billing System

#### 3.3.1 Features
- Create new sale transaction (bill)
- Select customer (by mobile or name+village)
- Select product variants and quantities
- Auto-calculate total with GST
- Track empty bottle return (for cylinders)
- Record payment (Cash/Cheque/UPI/Card/Credit)
- Generate and print bill
- Edit/cancel bill (with audit log)
- View bill history

#### 3.3.2 Transaction Flow
```
1. Select Date (default: today)
2. Search & Select Customer (by mobile or name+village)
3. Display Customer's Outstanding Balance + Empty Bottles Owed
4. Add Products:
   - Select Category → Product → Variant
   - Enter Quantity
   - Auto-fill price (editable by admin)
5. For returnable products (cylinders):
   - Enter "Empty Bottles Returned" count
6. Calculate Total:
   - Subtotal + GST = Total Amount
7. Payment:
   - Mode: Cash (default) / Cheque / UPI / Card / Credit
   - Amount Paid (can be partial)
   - If Cheque: capture Cheque Number, Bank, Date
8. Save Transaction → Generate Bill Number
9. Print / Save as PDF
```

#### 3.3.3 Transaction Data Fields
**Bill Header:**
| Field | Type | Notes |
|-------|------|-------|
| Bill Number | Auto | Format: BILL/YY-YY/0001 |
| Bill Date | Date | Default today, editable |
| Customer ID | FK | Links to customer |
| Subtotal | Decimal | Sum of line items |
| Discount | Decimal | Optional |
| GST Amount | Decimal | Calculated |
| Total Amount | Decimal | Final amount |
| Amount Paid | Decimal | Amount received |
| Balance Due | Decimal | Total - Paid |
| Payment Mode | Enum | Cash/Cheque/UPI/Card/Credit |
| Cheque Details | JSON | If cheque selected |
| Notes | Text | Optional remarks |
| Created By | FK | User who created |
| Status | Enum | Draft/Confirmed/Cancelled |

**Bill Line Items:**
| Field | Type |
|-------|------|
| Bill ID | FK |
| Product Variant ID | FK |
| Quantity | Integer |
| Rate | Decimal |
| Empty Returned | Integer (for cylinders) |
| GST Rate | Decimal |
| Line Total | Decimal |

#### 3.3.4 Bottle/Empty Tracking Logic (Critical)
For every cylinder sale:
- `Empty_Owed_Before = Customer's current empty balance`
- `New_Cylinders_Given = Quantity sold`
- `Empty_Returned_Now = Count returned today`
- `Empty_Owed_After = Empty_Owed_Before + New_Cylinders_Given - Empty_Returned_Now`

This gives a clear picture of how many empty cylinders each customer owes at any time.

#### 3.3.5 Payment/Cash Management
- Every bill has payment details
- Partial payment allowed
- Balance carries forward as outstanding
- Receipt voucher for standalone payments (no product sold)
- Daily cash book — sum of all cash received in a day
- Bank reconciliation for cheques/UPI

---

### 3.4 Module 4 — Bill Printing (A4 Format, 9 Bills per Page)

#### 3.4.1 Requirement
- Select date range (From Date → To Date)
- Fetch all bills in range
- Print on A4 paper with **9 bills per page** (3×3 grid layout)
- Format template provided by owner (to be incorporated)
- Each mini-bill includes: Bill No, Date, Customer Name + Village, Items, Total, Balance

#### 3.4.2 Print Options
- Print Preview before printing
- Save as PDF
- Direct print to printer
- Print single bill (full A4) OR bulk (9 per page)
- Customer-wise bill summary print

---

### 3.5 Module 5 — Reports & Dashboard

#### 3.5.1 Dashboard (Home Screen)
- Today's Sales Total
- Today's Cash Collected
- Today's Cylinder Sold Count
- Pending Empty Cylinders (by customer)
- Outstanding Dues Summary
- Quick Actions: New Bill, Add Customer, Search

#### 3.5.2 Reports
| Report | Description |
|--------|-------------|
| Daily Sales Report | Date-wise sales with payment summary |
| Customer Ledger | Complete history of a customer |
| Outstanding Report | Customers with pending dues |
| Empty Bottle Report | Customers with unreturned cylinders |
| Product-wise Sales | Which variant sold how much |
| Cash Book | Day-wise cash in/out |
| GST Report | Monthly GST summary for filing |
| Cheque Register | All cheques received with status |

---

### 3.6 Module 6 — User Management & Settings

- Admin user + Staff users
- Role-based permissions (Admin, Billing Staff, Viewer)
- Business profile (Shop Name, Address, GSTIN, Logo)
- Bill numbering format configuration
- GST rates configuration
- Backup & Restore (local + cloud)

---

## 4. Non-Functional Requirements

| Aspect | Requirement |
|--------|-------------|
| **Performance** | Bill creation < 2 seconds; Customer search < 500ms |
| **Offline Mode** | All core features work offline; sync when online |
| **Security** | Password-protected login, encrypted local DB, audit logs |
| **Backup** | Daily automatic local backup + optional cloud backup |
| **Scalability** | Support up to 1,00,000 customers and 10,00,000 transactions |
| **Usability** | Keyboard shortcuts, fast data entry, minimal clicks |
| **Language** | English + Gujarati + Hindi support (UI labels) |
| **Printing** | Support all standard Windows printers |

---

## 5. Database Schema (High-Level)

### Tables
1. `users` — App users with roles
2. `customers` — Customer master
3. `product_categories` — Category master
4. `products` — Product master
5. `product_variants` — Variants per product
6. `bills` — Transaction headers
7. `bill_items` — Line items
8. `payments` — Standalone payments
9. `empty_bottle_ledger` — Empty cylinder tracking per customer
10. `cheques` — Cheque register
11. `audit_logs` — All modifications logged
12. `settings` — App configuration

### Key Relationships
- `customer` 1 → N `bills`
- `bill` 1 → N `bill_items`
- `product` 1 → N `product_variants`
- `bill_item` N → 1 `product_variant`
- `customer` 1 → 1 `empty_bottle_ledger` (running balance)

---

## 6. API Endpoints (REST)

### Authentication
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `POST /api/auth/refresh`

### Customers
- `GET /api/customers` — list with filters
- `GET /api/customers/:id` — detail
- `POST /api/customers` — create
- `PUT /api/customers/:id` — update
- `DELETE /api/customers/:id` — soft delete
- `POST /api/customers/import` — bulk import
- `GET /api/customers/search?q=` — search
- `GET /api/customers/:id/ledger` — full history

### Products
- `GET /api/products`
- `POST /api/products`
- `PUT /api/products/:id`
- `DELETE /api/products/:id`
- `GET /api/products/variants`
- `POST /api/products/variants`

### Bills
- `GET /api/bills?from=&to=&customerId=`
- `POST /api/bills`
- `GET /api/bills/:id`
- `PUT /api/bills/:id`
- `DELETE /api/bills/:id`
- `GET /api/bills/print?from=&to=&format=9up`
- `GET /api/bills/:id/pdf`

### Reports
- `GET /api/reports/daily-sales`
- `GET /api/reports/outstanding`
- `GET /api/reports/empty-bottles`
- `GET /api/reports/cash-book`
- `GET /api/reports/gst`

---

## 7. Development Phases

### Phase 1 — MVP (Weeks 1-6)
- Authentication
- Customer management (CRUD + Import)
- Product management
- Basic billing (single bill creation)
- Payment recording
- Basic bill print (single A4)

### Phase 2 — Core Features (Weeks 7-10)
- Empty bottle tracking
- 9-bills-per-page A4 print
- Daily sales report
- Customer ledger
- Outstanding report

### Phase 3 — Advanced (Weeks 11-14)
- Dashboard with charts
- All reports
- Backup/Restore
- Multi-user with roles
- GST reports

### Phase 4 — Cross-Platform (Weeks 15-18)
- Web deployment
- Android build & test
- iOS build & test
- Cloud sync

---

## 8. Testing Requirements

- Unit tests for business logic (billing calculations, balance tracking)
- Integration tests for API endpoints
- UI tests for critical flows (new bill creation)
- User acceptance testing with real data
- Performance testing with 10,000+ customers
- Print testing on multiple printer models

---

## 9. Deliverables from Developer

1. Source code (Git repository with clear commits)
2. Windows installer (.exe / .msix)
3. APK for Android / IPA for iOS (Phase 4)
4. Database schema with migration scripts
5. API documentation (Postman collection / Swagger)
6. User manual (PDF with screenshots)
7. Admin manual
8. Deployment guide for self-hosting
9. 3 months post-delivery support
10. Training session (video recorded)

---

## 10. Acceptance Criteria

The project is considered complete when:
- ✅ All Phase 1, 2, 3 features work without critical bugs
- ✅ Windows installer works on Windows 10 and 11
- ✅ 1000+ test customers and 5000+ bills created successfully
- ✅ 9-bills-per-page A4 print matches provided template
- ✅ Excel import works with provided customer data format
- ✅ Empty bottle tracking is accurate for every customer
- ✅ Reports match manual calculations
- ✅ User training is completed
- ✅ No data loss during backup/restore

---

## 11. Commercial Terms (Suggested)

| Item | Details |
|------|---------|
| **Development Model** | Fixed Price OR Milestone-based |
| **Payment Milestones** | 20% advance, 30% after Phase 1, 30% after Phase 2, 20% after delivery |
| **Timeline** | 4-5 months for full desktop + 6 months total including mobile/web |
| **Support Period** | 3 months free bug fixes post-delivery |
| **Source Code** | Full ownership transferred to client |
| **IP Rights** | Owned by client |
| **Confidentiality** | NDA to be signed |
| **Estimated Budget Range** | ₹2.5 – 6 lakhs (depending on developer region and experience) |

---

## 12. Questions to Clarify with Client Before Starting

1. Please provide the **Excel format** for customer import (sample file)
2. Please provide the **A4 bill print template draft** (9 bills per page layout)
3. Do you need **GST-compliant tax invoices**? (Yes/No)
4. Current business size — how many customers and daily bills?
5. Do you have existing data to migrate? Format?
6. Number of users who will use the app simultaneously?
7. Do you need **multi-shop/multi-location** support in future?
8. Preferred language for UI — English / Gujarati / Hindi / all?
9. Do you need **WhatsApp bill sharing** integration?
10. Do you need **SMS notifications** for customers (dues reminder)?
11. Do you need **barcode/QR scanning** for cylinder tracking?
12. Preference for **cloud hosting** vs **local server**?
13. Budget and timeline expectations?

---

## 13. Risk Management

| Risk | Impact | Mitigation |
|------|--------|------------|
| Data loss | High | Daily automated backups, cloud sync |
| Print template mismatch | Medium | Get exact template upfront, print testing |
| Excel import errors | Medium | Validation, error reports, test with sample |
| Performance with large data | Medium | Indexing, pagination, archiving old data |
| User training gap | Medium | Video tutorials, in-app help |
| Future scope creep | High | Sign-off after each phase, change request process |

---

## 14. Glossary

- **Cylinder / Bottle:** LPG gas cylinder (empty shell)
- **Variant:** Different sizes/types of same product (e.g., 15kg, 21kg)
- **Empty Return:** When customer returns the empty cylinder shell
- **Deposit:** Refundable amount charged for cylinder shell
- **Outstanding:** Pending dues from customer
- **Ledger:** Complete transaction history of a customer

---

**Document Version:** 1.0
**Last Updated:** April 2026
**Prepared For:** Gas Cylinder Distribution Business Owner
**Intended Audience:** Software Developers / Development Agency