# Designing — UI Kit & Design System

> **Authoritative source for every design/UI decision in the SPBilling app.** If you are styling a screen, building a component, or picking a color — open the files below first. Do not invent new patterns.

---

## 1. Directory Layout

```
Designing/
├── ui-kit.html              ← Live component dictionary (open in browser)
├── spgas/
│   ├── app.html             ← Clickable prototype shell
│   ├── styles.css           ← 48 KB — full design system (tokens + every component)
│   ├── src/
│   │   ├── app.jsx          ← Router / root
│   │   ├── shell.jsx        ← Sidebar + topbar + status bar
│   │   ├── ui.jsx           ← Reusable primitives (Modal, Drawer, Toast, Field, Segmented, Kbd…)
│   │   ├── icons.jsx        ← Custom Lucide-style icon set (2 px stroke, outlined)
│   │   ├── data.jsx         ← SEED data + helpers (fmtINR, initials, highlight)
│   │   └── screens/         ← 9 reference screens (login, dashboard, newbill, bills,
│   │                          customers, products, reports, print, settings)
│   └── uploads/             ← Reference imagery from client
├── spgas.zip                ← Archive of the same (distribution artifact)
└── CLAUDE.md                ← This file
```

**Tech:** React 18 (UMD) + Babel standalone — zero build step. Any Flutter/native implementation must reproduce the tokens and components defined here, not re-design them.

---

## 2. Design Principles (ladder every decision to these)

1. **Speed over style** — staff make 100+ bills/day, every extra click is cost.
2. **Keyboard first** — a bill must be creatable without the mouse; tab order matters.
3. **Clarity** — tabular-nums, high contrast, one-word statuses.
4. **Forgiving** — auto-save drafts, confirm destructive actions, undo where possible.
5. **Familiar** — feels like Tally / Busy but modern; no retraining.
6. **Regional comfort** — ₹ everywhere, Indian lakh-crore grouping, DD-MMM-YYYY dates.

---

## 3. Design Tokens (from `spgas/styles.css`)

All tokens are CSS variables on `:root`. **Never hardcode — always use `var(--token)`.**

### Color — Brand (7 palettes, active = **teal**; switch via `<html data-brand="…">`)
`indigo` · `blue` · `teal` · `emerald` · `violet` · `rose` · `amber`. Each palette exposes `--brand-{50,100,200,500,600,700,800,900}`.

### Color — Semantic (fixed across brands)
- `--ok-{50,100,500,600,700}` → Paid, Success, Active
- `--warn-{50,100,500,600,700}` → Partial, Due, Empty pending
- `--err-{50,100,500,600,700}` → Unpaid, Overdue, Destructive
- `--info-{500,600}` → Informational

### Color — Neutrals (light theme)
`--bg` `#f7f8fb` · `--surface` `#ffffff` · `--surface-2` `#f1f3f8` · `--border` `#e4e7ee` · `--divider` `#eceff5` · `--text` `#0f172a` · `--text-2` `#475569` · `--text-3` `#94a3b8`.

### Typography
- Font: **Inter** (UI) · **JetBrains Mono** (numbers, codes, SKUs).
- Scale: `--fs-h1` 24/700 · `--fs-h2` 18/600 · `--fs-body` 14/400 · `--fs-sm` 12/400.
- **Always** apply `font-variant-numeric: tabular-nums` to amounts and counts.

### Spacing · Radius · Shadow
- Spacing scale (8 px base): `4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64`. No ad-hoc values.
- Radius: `--r-xs` 4 · `--r-sm` 6 · `--r-md` 10 · `--r-lg` 12 · `--r-xl` 16 · `999px` (pills).
- Elevation: `--sh-sm` cards · `--sh-md` popovers · `--sh-lg` modals · `--sh-xl` dialogs.

### Layout & Density
`--sidebar-w` 240 (collapsed 64) · `--topbar-h` 56 · `--statusbar-h` 32. Density toggle via `<html data-density="comfortable|compact">` — rewrites `--row-h`, `--input-h`, `--btn-h`, `--pad-card`, `--gap`, `--fs-*`.

### Icons
Custom Lucide-style set in `src/icons.jsx`. 2 px stroke, outlined, `currentColor`. Sizes: **16 px inline, 20 px in buttons, 24 px in navigation.** Usage: `<Icon name="plus" size={16}/>`.

---

## 4. Component Dictionary (canonical names + classes)

| Component | Class / API | Where it lives |
|---|---|---|
| Button | `.btn.primary / .secondary / .ghost / .danger` + `.sm/.lg/.block` | Everywhere |
| Icon Button | `.icon-btn-s` | Table rows, toolbars |
| Input | `.input`, `.input-with-icon > .ii + .input` | Forms |
| Textarea · Select | `textarea`, `.select` | Forms |
| Checkbox · Radio | `.checkbox`, `.radio` (custom box span) | Bulk select, settings |
| Segmented | `<Segmented options value onChange/>` | Date ranges, density |
| Filter Chip | `.filter-chip.on` | List filter bars |
| Badge | `.badge.ok/warn/err/brand/muted` | Tables, headers |
| Card | `.card > .card-h + .card-b` | Grouped content |
| Stat Card | `.stat`, `.stat.accent` | **Dashboard only** |
| Quick Action | `.qa-btn` | Dashboard shortcut row |
| Data Table | `.tbl-wrap > table.tbl` · `th.num` + `td.num` for right-align | Lists |
| Empty State | `.empty > .glyph + text + CTA` | Zero-data placeholders |
| Modal | `<Modal title footer/>` | Focused tasks, confirmations |
| Drawer | `<Drawer width/>` | Customer detail, notifications |
| Toast | `useToast().push({kind, title, msg})` | Global, top-right, auto-dismiss 4 s |
| Tabs · Pagination | `.tabs > .tab.on` · `.btn.secondary.sm` pair | Sub-views, long tables |
| Sidebar Nav Item | `.nav-item.active` + optional `.count` | Shell sidebar |
| Kbd hint | `<Kbd k="Ctrl+↵"/>` | Next to power actions |

### Domain components — billing only (don't reuse elsewhere)
- **Customer autocomplete** — `.cust-dropdown > .cust-opt.focused` (↑↓ Enter)
- **Selected customer card** — `.cust-selected` (name · mobile · prev due · empty pending)
- **Items table** — `.items-tbl` with `.cell-input` per cell; in-row product search
- **Bottles calculator** — `.bottles-calc` (Previous + New − Returned = Owing, live)
- **Totals** — `.totals > .row.sub / .row.grand` (sticky right rail on New Bill)
- **Payment mode cards** — `.pay-modes > .pay-mode.on` (5 modes always visible)
- **Mini-Bill** — `.a4 > .minibill` for the 9-up A4 print layout only

---

## 5. Screen Patterns (see `spgas/src/screens/`)

| Screen | File | Shell |
|---|---|---|
| Login | `login.jsx` | None — full-bleed |
| Dashboard | `dashboard.jsx` | Sidebar + topbar; stat-card row + quick actions + recent bills |
| New Bill | `newbill.jsx` | 2-column: items/customer on left, totals sticky right |
| Bills list · Customers · Products · Reports | `bills.jsx`, `customers.jsx`, `products.jsx`, `reports.jsx` | Sidebar + topbar + data table |
| Print Preview | `print.jsx` | Minimal chrome; A4 paper metaphor |
| Settings | `settings.jsx` | Sidebar + tabbed sections |

---

## 6. Do & Don't

**Do**
- Use `var(--token)` for every color, radius, shadow, spacing value.
- Right-align all numeric columns; `tabular-nums` on amounts.
- Format every rupee value with `fmtINR()` from `data.jsx`.
- Put the primary action on the **right** of a button group.
- Pair every colored badge with a text label (color is never the only signal).
- Auto-save New Bill drafts on each keystroke; confirm destructive actions in a modal.
- Show keyboard shortcuts (`<Kbd/>`) beside power actions (Save, Print, New).

**Don't**
- Don't invent new colors, radii, or spacings.
- Don't use emoji in production UI.
- Don't nest modals or use more than one primary button per screen.
- Don't use the `.items-tbl` pattern anywhere except New Bill.
- Don't use text smaller than 12 px on desktop.
- Don't hide required information behind tooltips.

---

## 7. Where to Look for What

| Need | File |
|---|---|
| A color / spacing / radius value | `spgas/styles.css` `:root` block |
| What a component looks like & when to use it | `ui-kit.html` (open in browser) |
| How a component is composed in React | `spgas/src/ui.jsx` + `screens/*.jsx` |
| Icon names available | `spgas/src/icons.jsx` (~45 icons) |
| Currency / initials / highlight helpers | `spgas/src/data.jsx` |
| A full screen reference | `spgas/src/screens/<name>.jsx` |

---

**Rule of thumb:** if the pattern you need isn't in `styles.css` + `ui-kit.html`, stop and ask — don't invent. Consistency is a feature.
