"use client";

import { useActionState } from "react";

import type { Dictionary } from "@/i18n/types";
import { archiveBrand, createBrand, restoreBrand } from "@/lib/brands/actions";
import type { ReferenceKind } from "@/lib/catalog-reference/helpers";
import { archiveProductType, createProductType, restoreProductType } from "@/lib/product-types/actions";
import { archiveUnit, createUnit, restoreUnit } from "@/lib/units/actions";
import type { CatalogActionState, CatalogStatus } from "@/types/catalog";

const INITIAL_STATE: CatalogActionState = { error: null, message: null };
const ACTIONS = {
  brand: { create: createBrand, archive: archiveBrand, restore: restoreBrand },
  unit: { create: createUnit, archive: archiveUnit, restore: restoreUnit },
  productType: {
    create: createProductType,
    archive: archiveProductType,
    restore: restoreProductType,
  },
};

export type ReferenceManagerItem = {
  id: string;
  name: string;
  detail: string | null;
  description: string | null;
  status: CatalogStatus;
  archivedAt: string | null;
};

function LifecycleForm({
  kind,
  item,
  dictionary,
}: {
  kind: ReferenceKind;
  item: ReferenceManagerItem;
  dictionary: Dictionary;
}) {
  const action = item.archivedAt ? ACTIONS[kind].restore : ACTIONS[kind].archive;
  const [state, formAction, pending] = useActionState(action, INITIAL_STATE);

  return (
    <form action={formAction}>
      <input type="hidden" name="reference_id" value={item.id} />
      <button
        type="submit"
        disabled={pending}
        className="text-sm font-bold text-emerald-700 hover:text-emerald-900 disabled:opacity-50"
      >
        {item.archivedAt ? dictionary.catalog.restore : dictionary.catalog.archive}
      </button>
      {state.error ? <p className="mt-1 text-xs text-red-700">{state.error}</p> : null}
      {state.message ? <p className="mt-1 text-xs text-emerald-700">{state.message}</p> : null}
    </form>
  );
}

export function CatalogReferenceManager({
  kind,
  items,
  dictionary,
}: {
  kind: ReferenceKind;
  items: ReferenceManagerItem[];
  dictionary: Dictionary;
}) {
  const [state, formAction, pending] = useActionState(ACTIONS[kind].create, INITIAL_STATE);
  const addLabel =
    kind === "brand"
      ? dictionary.catalog.addBrand
      : kind === "unit"
        ? dictionary.catalog.addUnit
        : dictionary.catalog.addProductType;

  return (
    <div className="grid gap-6 lg:grid-cols-[minmax(18rem,24rem)_minmax(0,1fr)] lg:items-start">
      <form action={formAction} className="border border-slate-200 bg-white p-5">
        <h2 className="text-lg font-bold text-slate-950">{addLabel}</h2>
        <div className="mt-5 grid gap-4">
          <label className="text-sm font-semibold text-slate-700">
            {dictionary.common.name}
            <input required name="name" className="mt-2 block w-full border border-slate-300 px-3 py-2.5 font-normal outline-none focus:border-emerald-600" />
          </label>
          {kind === "unit" ? (
            <label className="text-sm font-semibold text-slate-700">
              {dictionary.catalog.unitShortName}
              <input required name="short_name" className="mt-2 block w-full border border-slate-300 px-3 py-2.5 font-normal outline-none focus:border-emerald-600" />
            </label>
          ) : null}
          {kind === "productType" ? (
            <label className="text-sm font-semibold text-slate-700">
              {dictionary.catalog.code}
              <input name="code" className="mt-2 block w-full border border-slate-300 px-3 py-2.5 font-normal outline-none focus:border-emerald-600" />
            </label>
          ) : null}
          {kind !== "unit" ? (
            <label className="text-sm font-semibold text-slate-700">
              {dictionary.catalog.description}
              <textarea name="description" rows={3} className="mt-2 block w-full resize-y border border-slate-300 px-3 py-2.5 font-normal outline-none focus:border-emerald-600" />
            </label>
          ) : null}
          <label className="text-sm font-semibold text-slate-700">
            {dictionary.common.status}
            <select name="status" defaultValue="active" className="mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal">
              <option value="active">{dictionary.common.active}</option>
              <option value="inactive">{dictionary.common.inactive}</option>
            </select>
          </label>
        </div>
        {state.error ? <p className="mt-4 border-l-4 border-red-500 bg-red-50 p-3 text-sm text-red-800">{state.error}</p> : null}
        {state.message ? <p className="mt-4 border-l-4 border-emerald-500 bg-emerald-50 p-3 text-sm text-emerald-900">{state.message}</p> : null}
        <button type="submit" disabled={pending} className="mt-5 min-h-11 bg-emerald-700 px-5 py-2.5 text-sm font-bold text-white hover:bg-emerald-800 disabled:opacity-50">
          {pending ? dictionary.common.adding : addLabel}
        </button>
      </form>

      <div className="overflow-x-auto border border-slate-200 bg-white">
        <table className="w-full min-w-[600px] border-collapse text-left text-sm">
          <thead className="bg-slate-100 text-xs uppercase text-slate-600">
            <tr>
              <th className="px-4 py-3">{dictionary.common.name}</th>
              <th className="px-4 py-3">{dictionary.catalog.details}</th>
              <th className="px-4 py-3">{dictionary.common.status}</th>
              <th className="px-4 py-3 text-right">{dictionary.common.action}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-200">
            {items.map((item) => (
              <tr key={item.id} className={item.archivedAt ? "bg-slate-100 text-slate-500" : "text-slate-700"}>
                <th className="px-4 py-3 font-semibold text-slate-950">{item.name}</th>
                <td className="px-4 py-3">
                  {item.detail ?? item.description ?? "-"}
                  {item.detail && item.description ? <p className="mt-1 text-xs text-slate-500">{item.description}</p> : null}
                </td>
                <td className="px-4 py-3 font-semibold">
                  {item.archivedAt ? dictionary.catalog.archived : item.status === "active" ? dictionary.common.active : dictionary.common.inactive}
                </td>
                <td className="px-4 py-3 text-right"><LifecycleForm kind={kind} item={item} dictionary={dictionary} /></td>
              </tr>
            ))}
          </tbody>
        </table>
        {items.length === 0 ? <p className="px-4 py-10 text-center text-sm text-slate-500">{dictionary.catalog.noReferenceData}</p> : null}
      </div>
    </div>
  );
}
