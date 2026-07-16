import Link from "next/link";

import { LogoutButton } from "@/components/logout-button";
import { ROUTES } from "@/constants/routes";

export function OwnerHeader() {
  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex w-full max-w-7xl flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <Link href={ROUTES.OWNER_DASHBOARD} className="text-lg font-bold text-slate-950">
          Market POS
        </Link>
        <nav aria-label="Owner navigation" className="flex flex-wrap items-center gap-5">
          <Link
            href={ROUTES.OWNER_PRODUCTS}
            className="text-sm font-semibold text-slate-700 hover:text-emerald-700"
          >
            Products
          </Link>
          <Link
            href={ROUTES.OWNER_CATEGORIES}
            className="text-sm font-semibold text-slate-700 hover:text-emerald-700"
          >
            Categories
          </Link>
          <LogoutButton />
        </nav>
      </div>
    </header>
  );
}
