# Market POS — Project Plan

## Working branches

- `main` — stable version
- `dev` — active development
- `feature/auth`
- `feature/products`
- `feature/stock`
- `feature/sales`
- `feature/debts`
- `feature/shifts`
- `feature/reports`
- `feature/offline-sync`

## Sprint 0 — Project organization

### Goal

Prepare project workspace before coding.

### Tasks

- Create GitHub repository `market-pos`
- Add README.md
- Add docs folder
- Add project plan
- Add GitHub issues
- Add initial SQL schema
- Create Figma file for UX
- Create Notion project page
- Connect Codex to GitHub repository

### Result

The team has a clear development base and Codex can start working with small tasks.

---

## Sprint 1 — Project setup

### Goal

Create technical foundation.

### Tasks

- Create Next.js project
- Enable TypeScript
- Add Tailwind CSS
- Configure ESLint
- Configure Prettier
- Create base folders
- Create owner and seller layouts
- Add basic routes
- Deploy empty app to Vercel

### Result

The empty application runs locally and online.

---

## Sprint 2 — Database and auth

### Goal

Prepare core database and user roles.

### Tasks

- Apply initial SQL migration
- Create seed organization
- Create seed store
- Create seed owner
- Create seed seller
- Implement login
- Implement role-based redirect
- Protect owner and seller routes

### Result

Owner enters `/owner/dashboard`; seller enters `/seller/pos`.

---

## Sprint 3 — Products

### Goal

Owner can create and manage product catalog.

### Tasks

- Create categories UI
- Create product list
- Create product form
- Add barcode field
- Add minimum quantity
- Add product search
- Add product card

### Result

Products are ready for stock and sales modules.

---

## Sprint 4 — Stock income and batches

### Goal

Owner can add stock through product batches.

### Tasks

- Create stock income form
- Create product batch on income
- Store purchase price
- Store sale price at arrival
- Store expiration date
- Increase product current quantity
- Create stock movement

### Result

Products have real stock and stock history.

---

## Sprint 5 — POS sales

### Goal

Seller can quickly sell products.

### Tasks

- Create POS screen
- Add product search
- Add barcode search
- Add popular product buttons
- Add cart
- Add payment method
- Create sale
- Create sale items
- Decrease stock from batches
- Calculate profit
- Create payment
- Create operation log

### Result

Seller can sell products and stock decreases automatically.

---

## Sprint 6 — Debts

### Goal

Replace debt notebook with digital debt tracking.

### Tasks

- Create customers table UI
- Add customer search
- Create debt sale
- Increase customer debt
- Create debt entries
- Accept debt payment
- Decrease customer debt
- Show customer debt history

### Result

Debt sales and debt payments work correctly.

---

## Sprint 7 — Shifts

### Goal

Control seller shifts and cash.

### Tasks

- Open shift
- Close shift
- Calculate cash sales
- Calculate debt payments
- Calculate expected cash
- Enter actual cash
- Calculate difference
- Show shift report

### Result

Owner can control seller shift and cash difference.

---

## Sprint 8 — Reports

### Goal

Owner sees business control dashboard.

### Tasks

- Today sales
- Today profit
- Total debts
- Low stock count
- Out of stock count
- Reorder list
- Top selling products
- Top profit products
- Expiring products

### Result

Owner sees actionable business information.

---

## Sprint 9 — Offline-first sync

### Goal

Seller can work without internet.

### Tasks

- Add IndexedDB
- Cache products locally
- Cache customers locally
- Create local operation queue
- Save sales offline
- Save debt sales offline
- Save debt payments offline
- Add local_operation_id
- Add sync status UI
- Add manual sync button
- Add duplicate protection
- Add conflict handling

### Result

Seller can continue selling without internet and sync later.

---

## Sprint 10 — Store testing

### Goal

Test MVP in a real shop.

### Tasks

- Add 50–100 real products
- Test sales
- Test debt sales
- Test debt payments
- Test stock income
- Test shifts
- Test offline mode
- Test sync
- Collect seller feedback
- Collect owner feedback
- Create bug list

### Result

We understand if the product is ready for external pilot stores.
