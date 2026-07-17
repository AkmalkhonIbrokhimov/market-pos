"use client";

import Link from "next/link";
import { useActionState } from "react";

import { ROUTES } from "@/constants/routes";
import type { Dictionary } from "@/i18n/types";
import { createCategory, updateCategory } from "@/lib/categories/actions";
import type {
  CatalogActionState,
  CategoryFormValue,
  CategoryOption,
} from "@/types/catalog";

const INITIAL_STATE: CatalogActionState = { error: null, message: null };

type CategoryFormProps = {
  categories: CategoryOption[];
  dictionary: Dictionary;
  category?: CategoryFormValue;
  defaultParentId?: string | null;
};

export function CategoryForm({
  categories,
  dictionary,
  category,
  defaultParentId,
}: CategoryFormProps) {
  const action = category ? updateCategory : createCategory;
  const [state, formAction, isPending] = useActionState(action, INITIAL_STATE);
  const isSubcategory = !category && Boolean(defaultParentId);

  return (
    <form id="category-form" action={formAction} className="border border-slate-200 bg-white p-5 sm:p-6">
      {category ? <input type="hidden" name="category_id" value={category.id} /> : null}
      <div className="border-b border-slate-200 pb-4">
        <h2 className="text-lg font-bold text-slate-950">
          {category
            ? dictionary.catalog.editCategory
            : isSubcategory
              ? dictionary.catalog.addSubcategory
              : dictionary.catalog.addCategory}
        </h2>
        <p className="mt-1 text-sm text-slate-500">{dictionary.catalog.categoryFormDescription}</p>
      </div>

      <div className="mt-5 grid gap-5 md:grid-cols-2">
        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.common.name}
          <input
            required
            name="name"
            defaultValue={category?.name}
            autoComplete="off"
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.catalog.parentCategory}
          <select
            name="parent_id"
            defaultValue={category?.parentId ?? defaultParentId ?? ""}
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          >
            <option value="">{dictionary.catalog.noParentCategory}</option>
            {categories.map((option) => (
              <option key={option.id} value={option.id}>
                {`${"— ".repeat(option.depth)}${option.name}`}
              </option>
            ))}
          </select>
        </label>

        <label className="block text-sm font-semibold text-slate-700 md:col-span-2">
          {dictionary.catalog.categoryDescription}
          <textarea
            name="description"
            rows={3}
            defaultValue={category?.description ?? ""}
            className="mt-2 block w-full resize-y border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.common.status}
          <select
            name="status"
            defaultValue={category?.status ?? "active"}
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          >
            <option value="active">{dictionary.common.active}</option>
            <option value="inactive">{dictionary.common.inactive}</option>
          </select>
        </label>

        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.catalog.sortOrder}
          <input
            name="sort_order"
            type="number"
            step="1"
            defaultValue={category?.sortOrder ?? 0}
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>
      </div>

      {state.error ? (
        <p role="alert" className="mt-4 border-l-4 border-red-500 bg-red-50 p-3 text-sm text-red-800">
          {state.error}
        </p>
      ) : null}
      {state.message ? (
        <p role="status" className="mt-4 border-l-4 border-emerald-500 bg-emerald-50 p-3 text-sm text-emerald-900">
          {state.message}
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
            : category
              ? dictionary.catalog.saveCategory
              : isSubcategory
                ? dictionary.catalog.addSubcategory
                : dictionary.catalog.addCategory}
        </button>
        {category ? (
          <Link href={ROUTES.OWNER_CATEGORIES} className="text-sm font-semibold text-slate-600 hover:text-slate-950">
            {dictionary.common.cancel}
          </Link>
        ) : null}
      </div>
    </form>
  );
}
