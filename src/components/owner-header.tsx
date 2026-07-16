import Link from "next/link";

import { LogoutButton } from "@/components/logout-button";
import { ROUTES } from "@/constants/routes";
import type { Dictionary } from "@/i18n/types";

export function OwnerHeader({ dictionary }: { dictionary: Dictionary }) {
  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex w-full max-w-7xl flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <Link href={ROUTES.OWNER_DASHBOARD} className="text-lg font-bold text-slate-950">
          Market POS
        </Link>
        <nav aria-label={dictionary.navigation.ownerAria} className="flex flex-wrap items-center gap-5">
          <Link
            href={ROUTES.OWNER_PRODUCTS}
            className="text-sm font-semibold text-slate-700 hover:text-emerald-700"
          >
            {dictionary.navigation.products}
          </Link>
          <Link
            href={ROUTES.OWNER_CATEGORIES}
            className="text-sm font-semibold text-slate-700 hover:text-emerald-700"
          >
            {dictionary.navigation.categories}
          </Link>
          <Link
            href={ROUTES.OWNER_STOCK_INCOME}
            className="text-sm font-semibold text-slate-700 hover:text-emerald-700"
          >
            {dictionary.stock.income}
          </Link>
          <Link
            href={ROUTES.OWNER_STOCK_INCOME_HISTORY}
            className="text-sm font-semibold text-slate-700 hover:text-emerald-700"
          >
            {dictionary.stock.history}
          </Link>
          <LogoutButton label={dictionary.navigation.logout} />
        </nav>
      </div>
    </header>
  );
}
