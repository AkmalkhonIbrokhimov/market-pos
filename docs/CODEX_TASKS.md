# Codex Task Prompts — Sprint 0 / Sprint 1

Use these prompts one by one. Do not ask Codex to build the whole system at once.

---

## Task 1 — Initialize project

Create a new Next.js app for an offline-first retail POS system.

Requirements:

- Use TypeScript.
- Use App Router.
- Add Tailwind CSS.
- Create basic folder structure:
  - `src/app`
  - `src/components`
  - `src/lib`
  - `src/services`
  - `src/types`
  - `src/constants`
  - `docs`
  - `supabase/migrations`
- Add placeholder pages:
  - `/login`
  - `/owner/dashboard`
  - `/seller/pos`
- Do not implement database logic yet.
- Do not implement sales logic yet.

Acceptance criteria:

- App runs locally with `npm run dev`.
- `/login`, `/owner/dashboard`, `/seller/pos` open successfully.
- Tailwind styles work.

---

## Task 2 — Add initial database migration

Add Supabase/PostgreSQL migration file:

`supabase/migrations/0001_initial_schema.sql`

Use the schema from this repository.

Acceptance criteria:

- Migration file is added.
- Do not modify frontend.
- Do not implement API.
- Do not add fake business logic.

---

## Task 3 — Create layouts

Create separate layouts for owner and seller.

Requirements:

- Owner layout has navigation:
  - Dashboard
  - Products
  - Stock
  - Sales
  - Debts
  - Reports
  - Sync
- Seller layout has navigation:
  - POS
  - Debts
  - Shift
  - Sync
- Use simple responsive Tailwind styling.
- Do not implement auth yet.

Acceptance criteria:

- Owner pages use owner layout.
- Seller pages use seller layout.
- Mobile view is readable.

---

## Task 4 — Add role constants and route map

Create constants for roles, permissions and routes.

Files:

- `src/constants/roles.ts`
- `src/constants/routes.ts`
- `src/constants/permissions.ts`

Roles:

- owner
- seller
- service_admin

Acceptance criteria:

- Constants are typed.
- No hardcoded role strings inside pages where avoidable.
