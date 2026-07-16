import type { Metadata } from "next";
import Link from "next/link";

import { OwnerHeader } from "@/components/owner-header";
import { ROUTES } from "@/constants/routes";
import { getDictionary, getLocale } from "@/i18n/server";
import { requireOwnerManager } from "@/lib/auth/guards";
import { listAccessibleStores, listIncomeHistory } from "@/services/stock";

export const metadata: Metadata = { title: "Income history" };
export const dynamic = "force-dynamic";

type IncomeHistoryPageProps = {
  searchParams: Promise<{ created?: string | string[]; search?: string | string[] }>;
};

function formatNumber(value: number, locale: string, maximumFractionDigits = 3): string {
  return new Intl.NumberFormat(locale, { maximumFractionDigits }).format(value);
}

function formatDate(value: string | null, locale: string): string {
  if (!value) {
    return "-";
  }

  return new Intl.DateTimeFormat(locale, { dateStyle: "medium" }).format(
    new Date(`${value}T00:00:00Z`),
  );
}

export default async function IncomeHistoryPage({ searchParams }: IncomeHistoryPageProps) {
  const [currentUser, dictionary, locale, params] = await Promise.all([
    requireOwnerManager(),
    getDictionary(),
    getLocale(),
    searchParams,
  ]);
  const stores = await listAccessibleStores(currentUser.profile.id);
  const records = await listIncomeHistory(stores.map((store) => store.id));
  const rawSearch = params.search;
  const search = (Array.isArray(rawSearch) ? rawSearch[0] : rawSearch ?? "").trim();
  const normalizedSearch = search.toLocaleLowerCase();
  const visibleRecords = normalizedSearch
    ? records.filter(
        (record) =>
          record.productName.toLocaleLowerCase().includes(normalizedSearch) ||
          record.productBarcode?.toLocaleLowerCase().includes(normalizedSearch),
      )
    : records;
  const created = (Array.isArray(params.created) ? params.created[0] : params.created) === "1";

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-5 border-b border-slate-200 pb-6 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.eyebrow}</p>
            <h1 className="mt-2 text-3xl font-bold text-slate-950">{dictionary.stock.history}</h1>
            <p className="mt-2 text-sm text-slate-600">{dictionary.stock.historyDescription}</p>
          </div>
          <Link
            href={ROUTES.OWNER_STOCK_INCOME}
            className="bg-emerald-700 px-4 py-2.5 text-sm font-bold text-white hover:bg-emerald-800"
          >
            {dictionary.stock.addIncome}
          </Link>
        </div>

        {created ? (
          <p className="mt-6 border-l-4 border-emerald-600 bg-emerald-50 p-4 text-sm font-semibold text-emerald-900">
            {dictionary.stock.success}
          </p>
        ) : null}

        <form className="mt-6 flex max-w-xl gap-3" role="search">
          <label htmlFor="income-search" className="sr-only">
            {dictionary.stock.searchHistory}
          </label>
          <input
            id="income-search"
            name="search"
            defaultValue={search}
            placeholder={dictionary.stock.searchHistory}
            className="min-w-0 flex-1 border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
          <button
            type="submit"
            className="bg-slate-900 px-4 py-2.5 text-sm font-bold text-white hover:bg-slate-800"
          >
            {dictionary.common.search}
          </button>
        </form>

        <div className="mt-6 overflow-x-auto border border-slate-200 bg-white">
          <table className="w-full min-w-[1150px] border-collapse text-left text-sm">
            <thead className="bg-slate-100 text-xs uppercase text-slate-600">
              <tr>
                <th scope="col" className="px-4 py-3 font-bold">{dictionary.stock.receivedDate}</th>
                <th scope="col" className="px-4 py-3 font-bold">{dictionary.stock.product}</th>
                <th scope="col" className="px-4 py-3 font-bold">{dictionary.stock.supplier}</th>
                <th scope="col" className="px-4 py-3 text-right font-bold">{dictionary.stock.quantity}</th>
                <th scope="col" className="px-4 py-3 text-right font-bold">{dictionary.stock.remainingQuantity}</th>
                <th scope="col" className="px-4 py-3 text-right font-bold">{dictionary.stock.purchasePrice}</th>
                <th scope="col" className="px-4 py-3 text-right font-bold">{dictionary.stock.salePriceAtArrival}</th>
                <th scope="col" className="px-4 py-3 font-bold">{dictionary.stock.expirationDate}</th>
                <th scope="col" className="px-4 py-3 font-bold">{dictionary.stock.comment}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {visibleRecords.map((record) => (
                <tr key={record.id} className="text-slate-700 hover:bg-slate-50">
                  <td className="whitespace-nowrap px-4 py-3">{formatDate(record.receivedDate, locale)}</td>
                  <th scope="row" className="px-4 py-3 font-semibold text-slate-950">
                    {record.productName}
                    {record.productBarcode ? (
                      <span className="mt-1 block font-mono text-xs font-normal text-slate-500">
                        {record.productBarcode}
                      </span>
                    ) : null}
                  </th>
                  <td className="px-4 py-3">{record.supplierName ?? dictionary.stock.noSupplier}</td>
                  <td className="px-4 py-3 text-right tabular-nums">
                    {formatNumber(record.initialQuantity, locale)}
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums">
                    {formatNumber(record.remainingQuantity, locale)}
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums">
                    {formatNumber(record.purchasePrice, locale, 2)}
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums">
                    {formatNumber(record.salePriceAtArrival, locale, 2)}
                  </td>
                  <td className="whitespace-nowrap px-4 py-3">
                    {formatDate(record.expirationDate, locale)}
                  </td>
                  <td className="max-w-64 px-4 py-3">{record.comment ?? "-"}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {visibleRecords.length === 0 ? (
            <p className="border-t border-slate-200 px-4 py-10 text-center text-sm text-slate-500">
              {search ? dictionary.stock.noSearchResults : dictionary.stock.noRecords}
            </p>
          ) : null}
        </div>
      </main>
    </div>
  );
}
