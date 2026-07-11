# Market POS

Offline-first retail management system for small shops.

## Project goal

Market POS is a web/PWA system for small retail stores that helps owners control:

- products;
- stock;
- sales;
- debts;
- shifts;
- profit;
- reorder list;
- offline sales and synchronization.

The system is designed for small shops where internet can be unstable. The seller must be able to continue selling even when there is no internet.

## Core idea

Seller needs speed.  
Owner needs control.

The product has two main modes:

1. **Seller mode** — fast POS screen for sales, debts, shift and sync.
2. **Owner mode** — dashboard, products, stock, reports, debts and control.

## MVP scope

### Included in MVP

- Auth and roles
- Owner and seller interfaces
- Products and categories
- Stock income and product batches
- Fast sales screen
- Debt sales
- Debt payments
- Shifts
- Basic reports
- Reorder list
- Offline-first seller workflow
- Manual and automatic sync
- Operation logs

### Not included in MVP

- Fiscal receipts
- Online cash register integration
- Tax integration
- Click/Payme integration
- SMS
- Loyalty program
- Full CRM
- Multi-branch offline server
- AI recommendations

These modules are planned for later versions.

## Tech stack

- Frontend: Next.js + React + TypeScript
- UI: Tailwind CSS
- Backend: Next.js API / Server Actions
- Database: Supabase PostgreSQL
- Auth: Supabase Auth or custom auth layer
- Offline DB: IndexedDB
- Hosting: Vercel
- Code: GitHub
- AI coding assistant: Codex

## Main roles

### Owner

Can manage the store, products, stock, sellers, reports, debts and shifts.

### Seller

Can open shift, sell products, sell in debt, accept debt payments, close shift and sync offline operations.

### Service admin

Future SaaS role for managing organizations, tariffs and subscriptions.

## Development strategy

The project is developed step by step:

1. Sprint 0 — project organization
2. Sprint 1 — project setup
3. Sprint 2 — database and auth
4. Sprint 3 — products
5. Sprint 4 — stock income and batches
6. Sprint 5 — POS sales
7. Sprint 6 — debts
8. Sprint 7 — shifts
9. Sprint 8 — reports
10. Sprint 9 — offline-first sync
11. Sprint 10 — store testing

## Repository structure

```text
src/
  app/
    login/
    owner/
    seller/
    api/
  components/
  lib/
  services/
  types/
  constants/

docs/
  PROJECT_PLAN.md
  GITHUB_ISSUES.md

supabase/
  migrations/
    0001_initial_schema.sql
```

## First target

The first technical goal is:

- create the base project;
- create database schema;
- implement auth and roles;
- allow owner to add products;
- allow seller to see products in POS screen.

## Definition of Done

A task is done only if:

- it works in the UI;
- it saves data correctly;
- it respects user roles;
- it has clear error handling;
- important operations are logged;
- it works on mobile;
- seller operations are designed with offline-first in mind.
