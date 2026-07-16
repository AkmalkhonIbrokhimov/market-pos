"use client";

import Link from "next/link";
import { useActionState, useState } from "react";

import { ROUTES } from "@/constants/routes";
import type { Dictionary, Locale } from "@/i18n/types";
import { addStockIncome } from "@/lib/stock/actions";
import type { StockActionState, StockProduct, StockStore, Supplier } from "@/types/stock";

const INITIAL_STATE: StockActionState = { error: null };
type SupplierMode = "none" | "existing" | "new";

type StockIncomeFormProps = {
  dictionary: Dictionary;
  locale: Locale;
  products: StockProduct[];
  stores: StockStore[];
  suppliers: Supplier[];
};

function formatNumber(value: number, locale: Locale, maximumFractionDigits = 3): string {
  return new Intl.NumberFormat(locale, { maximumFractionDigits }).format(value);
}

export function StockIncomeForm({
  dictionary,
  locale,
  products,
  stores,
  suppliers,
}: StockIncomeFormProps) {
  const [state, formAction, isPending] = useActionState(addStockIncome, INITIAL_STATE);
  const [productSearch, setProductSearch] = useState("");
  const [supplierMode, setSupplierMode] = useState<SupplierMode>("none");
  const canSubmit = stores.length > 0 && products.length > 0;
  const normalizedProductSearch = productSearch.trim().toLocaleLowerCase();
  const visibleProducts = normalizedProductSearch
    ? products.filter(
        (product) =>
          product.name.toLocaleLowerCase().includes(normalizedProductSearch) ||
          product.barcode?.toLocaleLowerCase().includes(normalizedProductSearch),
      )
    : products;

  return (
    <form action={formAction} className="border border-slate-200 bg-white p-5 sm:p-6">
      <div className="grid gap-5 md:grid-cols-2">
        {stores.length === 1 ? (
          <div className="block text-sm font-semibold text-slate-700">
            {dictionary.stock.store}
            <p className="mt-2 min-h-11 border border-slate-200 bg-slate-50 px-3 py-2.5 font-normal text-slate-950">
              {stores[0].name}
            </p>
            <input type="hidden" name="store_id" value={stores[0].id} />
          </div>
        ) : (
          <label className="block text-sm font-semibold text-slate-700">
            {dictionary.stock.store}
            <select
              required
              name="store_id"
              defaultValue=""
              className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
            >
              <option value="" disabled>
                {dictionary.stock.selectStore}
              </option>
              {stores.map((store) => (
                <option key={store.id} value={store.id}>
                  {store.name}
                </option>
              ))}
            </select>
          </label>
        )}

        <div className="md:col-span-2">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <label htmlFor="stock-product" className="text-sm font-semibold text-slate-700">
              {dictionary.stock.product}
            </label>
            <Link
              href={ROUTES.OWNER_NEW_PRODUCT}
              className="text-sm font-semibold text-emerald-700 hover:text-emerald-800"
            >
              {dictionary.stock.missingProductLink}
            </Link>
          </div>
          <input
            type="search"
            value={productSearch}
            onChange={(event) => setProductSearch(event.target.value)}
            placeholder={dictionary.stock.productSearch}
            aria-label={dictionary.stock.productSearch}
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 text-sm font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
          <select
            id="stock-product"
            required
            name="product_id"
            defaultValue=""
            aria-describedby="stock-product-helper"
            className="mt-3 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          >
            <option value="" disabled>
              {dictionary.stock.selectProduct}
            </option>
            {visibleProducts.map((product) => (
              <option key={product.id} value={product.id}>
                {product.name} · {product.barcode ?? "-"} · {formatNumber(product.currentQuantity, locale)} {product.unit} · {formatNumber(product.salePrice, locale, 2)}
              </option>
            ))}
          </select>
          {visibleProducts.length === 0 && products.length > 0 ? (
            <p className="mt-2 text-sm font-medium text-amber-800">
              {dictionary.stock.noProductMatches}
            </p>
          ) : null}
          <p id="stock-product-helper" className="mt-2 text-xs leading-5 text-slate-500">
            {dictionary.stock.productHelper}
          </p>
        </div>

        <label className="block text-sm font-semibold text-slate-700 md:col-span-2">
          {dictionary.stock.supplierMode}
          <select
            value={supplierMode}
            onChange={(event) => setSupplierMode(event.target.value as SupplierMode)}
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          >
            <option value="none">{dictionary.stock.supplierNone}</option>
            <option value="existing" disabled={suppliers.length === 0}>
              {dictionary.stock.supplierExisting}
            </option>
            <option value="new">{dictionary.stock.supplierNew}</option>
          </select>
          <span className="mt-1.5 block text-xs font-normal leading-5 text-slate-500">
            {dictionary.stock.supplierHelper}
          </span>
        </label>

        {supplierMode === "existing" ? (
          <label className="block text-sm font-semibold text-slate-700 md:col-span-2">
            {dictionary.stock.supplier}
            <select
              required
              name="supplier_id"
              defaultValue=""
              className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
            >
              <option value="" disabled>
                {dictionary.stock.selectSupplier}
              </option>
              {suppliers.map((supplier) => (
                <option key={supplier.id} value={supplier.id}>
                  {supplier.name}
                </option>
              ))}
            </select>
          </label>
        ) : null}

        {supplierMode === "new" ? (
          <label className="block text-sm font-semibold text-slate-700 md:col-span-2">
            {dictionary.stock.newSupplier}
            <input
              required
              name="quick_supplier_name"
              autoComplete="off"
              className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
            />
          </label>
        ) : null}

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.stock.quantity}
          <input
            required
            name="quantity"
            type="number"
            min="0.001"
            step="0.001"
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.stock.purchasePrice}
          <input
            required
            name="purchase_price"
            type="number"
            min="0"
            step="0.01"
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.stock.salePriceAtArrival}
          <input
            name="sale_price_at_arrival"
            type="number"
            min="0"
            step="0.01"
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
          <span className="mt-1.5 block text-xs font-normal text-slate-500">
            {dictionary.stock.salePriceHint}
          </span>
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.stock.expirationDate}
          <input
            name="expiration_date"
            type="date"
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="block text-sm font-semibold text-slate-700 md:col-span-2">
          {dictionary.stock.comment}
          <textarea
            name="comment"
            rows={3}
            className="mt-2 block w-full resize-y border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>
      </div>

      {state.error ? (
        <p role="alert" className="mt-5 border-l-4 border-red-500 bg-red-50 p-3 text-sm text-red-800">
          {state.error}
        </p>
      ) : null}

      <div className="mt-6 flex flex-wrap items-center gap-4 border-t border-slate-200 pt-5">
        <button
          type="submit"
          disabled={isPending || !canSubmit}
          className="min-h-11 bg-emerald-700 px-5 py-2.5 text-sm font-bold text-white hover:bg-emerald-800 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {isPending ? dictionary.stock.addingIncome : dictionary.stock.addIncome}
        </button>
        <Link
          href={ROUTES.OWNER_STOCK_INCOME_HISTORY}
          className="text-sm font-semibold text-slate-600 hover:text-slate-950"
        >
          {dictionary.stock.history}
        </Link>
      </div>
    </form>
  );
}
