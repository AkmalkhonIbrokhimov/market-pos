"use client";

import { useActionState } from "react";

import { createCategory } from "@/lib/categories/actions";
import type { Dictionary } from "@/i18n/types";
import type { CatalogActionState } from "@/types/catalog";

const INITIAL_STATE: CatalogActionState = { error: null };

export function CategoryForm({ dictionary }: { dictionary: Dictionary }) {
  const [state, formAction, isPending] = useActionState(createCategory, INITIAL_STATE);

  return (
    <form action={formAction} className="border border-slate-200 bg-white p-5">
      <h2 className="text-lg font-bold text-slate-950">{dictionary.catalog.addCategory}</h2>
      <div className="mt-5 grid gap-4 sm:grid-cols-[minmax(0,1fr)_11rem_auto] sm:items-end">
        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.common.name}
          <input
            required
            name="name"
            autoComplete="off"
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
        </label>
        <label className="block text-sm font-semibold text-slate-700">
          {dictionary.common.status}
          <select
            name="status"
            defaultValue="active"
            className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          >
            <option value="active">{dictionary.common.active}</option>
            <option value="inactive">{dictionary.common.inactive}</option>
          </select>
        </label>
        <button
          type="submit"
          disabled={isPending}
          className="min-h-11 bg-emerald-700 px-5 py-2.5 text-sm font-bold text-white hover:bg-emerald-800 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {isPending ? dictionary.common.adding : dictionary.catalog.addCategory}
        </button>
      </div>
      {state.error ? (
        <p role="alert" className="mt-4 border-l-4 border-red-500 bg-red-50 p-3 text-sm text-red-800">
          {state.error}
        </p>
      ) : null}
    </form>
  );
}
