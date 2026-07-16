import type { Metadata } from "next";
import Link from "next/link";

import { OwnerHeader } from "@/components/owner-header";
import { StockIncomeForm } from "@/components/stock-income-form";
import { ROUTES } from "@/constants/routes";
import { getDictionary, getLocale } from "@/i18n/server";
import { requireOwnerManager } from "@/lib/auth/guards";
import { listAccessibleStores, listStockProducts } from "@/services/stock";
import { listSuppliers } from "@/services/suppliers";

export const metadata: Metadata = { title: "Stock income" };
export const dynamic = "force-dynamic";

export default async function StockIncomePage() {
  const [currentUser, dictionary, locale] = await Promise.all([
    requireOwnerManager(),
    getDictionary(),
    getLocale(),
  ]);
  const organizationId = currentUser.profile.organizationId;
  const [stores, products, suppliers] = await Promise.all([
    listAccessibleStores(currentUser.profile.id),
    organizationId ? listStockProducts(organizationId) : Promise.resolve([]),
    organizationId ? listSuppliers(organizationId) : Promise.resolve([]),
  ]);

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-5 border-b border-slate-200 pb-6 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.eyebrow}</p>
            <h1 className="mt-2 text-3xl font-bold text-slate-950">{dictionary.stock.income}</h1>
            <p className="mt-2 text-sm text-slate-600">{dictionary.stock.incomeDescription}</p>
          </div>
          <Link
            href={ROUTES.OWNER_STOCK_INCOME_HISTORY}
            className="border border-slate-300 bg-white px-4 py-2.5 text-sm font-bold text-slate-700 hover:border-slate-400 hover:text-slate-950"
          >
            {dictionary.stock.history}
          </Link>
        </div>

        {!organizationId ? (
          <p className="mt-6 border-l-4 border-amber-500 bg-amber-50 p-4 text-sm text-amber-900">
            {dictionary.stock.errors.noOrganization}
          </p>
        ) : null}
        {stores.length === 0 ? (
          <p className="mt-6 border-l-4 border-amber-500 bg-amber-50 p-4 text-sm text-amber-900">
            {dictionary.stock.noStores}
          </p>
        ) : null}
        {products.length === 0 ? (
          <p className="mt-6 border-l-4 border-amber-500 bg-amber-50 p-4 text-sm text-amber-900">
            {dictionary.stock.noProducts}
          </p>
        ) : null}

        <div className="mt-6">
          <StockIncomeForm
            dictionary={dictionary}
            locale={locale}
            products={products}
            stores={stores}
            suppliers={suppliers}
          />
        </div>
      </main>
    </div>
  );
}
