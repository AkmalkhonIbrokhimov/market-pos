# GitHub Issues — Sprint 0 and MVP Backlog

## Labels to create

- `epic`
- `setup`
- `database`
- `auth`
- `frontend`
- `backend`
- `products`
- `stock`
- `sales`
- `debts`
- `shifts`
- `reports`
- `offline`
- `sync`
- `testing`
- `bug`
- `priority-high`
- `priority-medium`
- `priority-low`

---

## EPIC 1 — Project setup

### Issue: Create initial Next.js project

Labels: `setup`, `frontend`, `priority-high`

Body:

Create the initial Next.js application with TypeScript.

Acceptance criteria:

- Next.js app created
- TypeScript enabled
- App runs locally
- Default page replaced with project placeholder
- README updated with local run commands

---

### Issue: Configure Tailwind CSS

Labels: `setup`, `frontend`, `priority-high`

Body:

Add and configure Tailwind CSS.

Acceptance criteria:

- Tailwind installed
- Global styles configured
- Basic UI test component uses Tailwind classes
- Mobile-first layout is supported

---

### Issue: Create base project folder structure

Labels: `setup`, `priority-high`

Body:

Create the base folder structure for the project.

Acceptance criteria:

- `src/app`
- `src/components`
- `src/lib`
- `src/services`
- `src/types`
- `src/constants`
- `docs`
- `supabase/migrations`

---

## EPIC 2 — Database schema

### Issue: Add initial Supabase/PostgreSQL schema

Labels: `database`, `backend`, `priority-high`

Body:

Add initial database migration for MVP entities.

Tables:

- organizations
- stores
- users
- user_store_access
- categories
- products
- product_batches
- stock_movements
- customers
- sales
- sale_items
- payments
- debt_entries
- debt_payments
- shifts
- operation_logs
- devices
- sync_operations

Acceptance criteria:

- Migration applies without error
- Foreign keys are valid
- Basic indexes exist
- Sync tables exist
- Important status/type checks exist

---

### Issue: Add seed data for first test store

Labels: `database`, `testing`, `priority-medium`

Body:

Create seed data for the first test store.

Acceptance criteria:

- One organization
- One store
- One owner user
- One seller user
- Several categories
- Several test products

---

## EPIC 3 — Auth and roles

### Issue: Implement login page

Labels: `auth`, `frontend`, `backend`, `priority-high`

Body:

Create login page for owner and seller.

Acceptance criteria:

- User can enter phone/login and password
- Invalid credentials show error
- Successful login redirects by role
- First version can use simple auth implementation

---

### Issue: Implement role-based route protection

Labels: `auth`, `backend`, `priority-high`

Body:

Protect owner and seller routes by role.

Acceptance criteria:

- Owner can access `/owner/*`
- Seller can access `/seller/*`
- Seller cannot access owner dashboard
- Unauthorized user redirects to login

---

## EPIC 4 — Products

### Issue: Create product list page

Labels: `products`, `frontend`, `backend`, `priority-high`

Body:

Owner can view product list.

Acceptance criteria:

- Shows product name
- Shows category
- Shows sale price
- Shows current quantity
- Shows min quantity
- Supports search

---

### Issue: Create add product form

Labels: `products`, `frontend`, `backend`, `priority-high`

Body:

Owner can add new product.

Acceptance criteria:

- Product name required
- Category optional/required based on implementation
- Barcode optional
- Sale price required
- Min quantity optional
- Product status active by default

---

## EPIC 5 — Stock income and batches

### Issue: Implement stock income form

Labels: `stock`, `backend`, `frontend`, `priority-high`

Body:

Owner can add stock income for a product.

Acceptance criteria:

- Select product
- Enter quantity
- Enter purchase price
- Enter sale price
- Enter expiration date optional
- Creates product batch
- Creates stock movement
- Updates product current quantity

---

## EPIC 6 — POS sales

### Issue: Create seller POS screen

Labels: `sales`, `frontend`, `priority-high`

Body:

Create fast seller POS screen.

Acceptance criteria:

- Product search
- Barcode search field
- Cart
- Quantity plus/minus
- Total amount
- Payment button
- Debt sale button

---

### Issue: Implement regular sale logic

Labels: `sales`, `backend`, `priority-high`

Body:

Create backend logic for regular sale.

Acceptance criteria:

- Requires open shift
- Checks stock
- Creates sale
- Creates sale items
- Decreases batch quantities
- Creates stock movements
- Creates payment
- Calculates profit
- Creates operation log

---

## EPIC 7 — Debts

### Issue: Implement customers and debt sales

Labels: `debts`, `backend`, `frontend`, `priority-high`

Body:

Implement customer debt workflow.

Acceptance criteria:

- Add customer
- Search customer
- Create debt sale
- Increase customer debt
- Create debt entry
- Show customer total debt

---

### Issue: Implement debt payment

Labels: `debts`, `backend`, `frontend`, `priority-high`

Body:

Allow seller/owner to accept debt payment.

Acceptance criteria:

- Select customer
- Enter amount
- Select payment method
- Decrease customer debt
- Create debt payment
- Create debt entry
- Include cash debt payment in shift

---

## EPIC 8 — Shifts

### Issue: Implement open and close shift

Labels: `shifts`, `backend`, `frontend`, `priority-high`

Body:

Seller can open and close shift.

Acceptance criteria:

- Seller can open shift
- Prevent duplicate open shift
- Seller can close shift
- Expected cash calculated
- Actual cash entered
- Difference calculated

---

## EPIC 9 — Reports

### Issue: Implement owner dashboard

Labels: `reports`, `frontend`, `backend`, `priority-high`

Body:

Create dashboard for owner.

Acceptance criteria:

- Today sales
- Today profit
- Total debts
- Low stock count
- Out of stock count
- Unsynced operations count

---

### Issue: Implement reorder list

Labels: `reports`, `stock`, `priority-medium`

Body:

Show products that need to be ordered.

Acceptance criteria:

- Products below min quantity
- Out of stock products
- Shows recommendation
- Owner can open product card

---

## EPIC 10 — Offline-first sync

### Issue: Implement local IndexedDB storage

Labels: `offline`, `sync`, `frontend`, `priority-high`

Body:

Add IndexedDB local storage for seller workflow.

Acceptance criteria:

- Products cached locally
- Customers cached locally
- Local operation queue created
- Queue statuses supported: pending, syncing, synced, error, conflict

---

### Issue: Implement offline sale queue

Labels: `offline`, `sales`, `sync`, `priority-high`

Body:

Allow sales to be saved offline.

Acceptance criteria:

- Sale saved locally when offline
- local_operation_id generated
- UI shows unsynced count
- Manual sync button sends operations
- Duplicate operations are not created on server

---

## EPIC 11 — Store testing

### Issue: Prepare first store test checklist

Labels: `testing`, `priority-high`

Body:

Prepare checklist for testing MVP in real store.

Acceptance criteria:

- 50–100 products added
- Sale tested
- Debt sale tested
- Debt payment tested
- Shift tested
- Offline tested
- Sync tested
- Seller feedback collected
- Owner feedback collected
