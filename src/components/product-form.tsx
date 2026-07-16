"use client";

import Link from "next/link";
import { useActionState } from "react";

import { ROUTES } from "@/constants/routes";
import type { Dictionary } from "@/i18n/types";
import { createProduct, updateProduct } from "@/lib/products/actions";
import type { CatalogActionState, Category, ProductFormValue } from "@/types/catalog";

const INITIAL_STATE: CatalogActionState = { error: null };

type ProductFormProps = {
  categories: Category[];
  dictionary: Dictionary;
  product?: ProductFormValue;
};

export function ProductForm({ categories, dictionary, product }: ProductFormProps) {
  const action = product ? updateProduct : createProduct;
  const [state, formAction, isPending] = useActionState(action, INITIAL_STATE);

  return (
    <form action={formAction} className="border border-slate-200 bg-white p-5 sm:p-6">
      {product ? <input type="hidden" name="product_id" value={product.id} /> : null}

      <div className="grid gap-5 md:grid-cols-2">
        <label className="block text-sm font-semibold text-slate-700 md:col-span-2">
          {dictionary.catalog.productName}
          <input
            required
            name="name"
            defaultValue={product?.name}
            autoComplete="off"
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.common.category}
          <select
            name="category_id"
            defaultValue={product?.categoryId ?? ""}
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          >
            <option value="">{dictionary.common.noCategory}</option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>
                {category.name}
              </option>
            ))}
          </select>
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.common.barcode}
          <input
            name="barcode"
            defaultValue={product?.barcode ?? ""}
            autoComplete="off"
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.common.unit}
          <input
            required
            name="unit"
            defaultValue={product?.unit ?? "шт"}
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.common.salePrice}
          <input
            required
            name="sale_price"
            type="number"
            min="0"
            step="0.01"
            defaultValue={product?.salePrice ?? ""}
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.common.minimumQuantity}
          <input
            required
            name="min_quantity"
            type="number"
            min="0"
            step="0.001"
            defaultValue={product?.minQuantity ?? 0}
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.common.status}
          <select
            name="status"
            defaultValue={product?.status ?? "active"}
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          >
            <option value="active">{dictionary.common.active}</option>
            <option value="inactive">{dictionary.common.inactive}</option>
          </select>
        </label>

        <label className="flex min-h-11 items-center gap-3 self-end border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm font-semibold text-slate-700">
          <input
            name="is_expirable"
            type="checkbox"
            defaultChecked={product?.isExpirable ?? false}
            className="size-4 accent-emerald-700"
          />
          {dictionary.catalog.expirable}
        </label>
      </div>

      <p className="mt-5 text-sm text-slate-500">
        {dictionary.catalog.quantityNote}
      </p>

      {state.error ? (
        <p role="alert" className="mt-4 border-l-4 border-red-500 bg-red-50 p-3 text-sm text-red-800">
          {state.error}
        </p>
      ) : null}

      <div className="mt-6 flex flex-wrap items-center gap-4 border-t border-slate-200 pt-5">
        <button
          type="submit"
          disabled={isPending}
          className="min-h-11 bg-emerald-700 px-5 py-2.5 text-sm font-bold text-white hover:bg-emerald-800 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {isPending
            ? dictionary.common.saving
            : product
              ? dictionary.catalog.saveProduct
              : dictionary.catalog.addProduct}
        </button>
        <Link
          href={ROUTES.OWNER_PRODUCTS}
          className="text-sm font-semibold text-slate-600 hover:text-slate-950"
        >
          {dictionary.common.cancel}
        </Link>
      </div>
    </form>
  );
}
