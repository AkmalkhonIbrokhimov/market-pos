"use client";

import { useActionState } from "react";

import type { Dictionary } from "@/i18n/types";
import { archiveProduct, restoreProduct } from "@/lib/products/actions";
import type { CatalogActionState } from "@/types/catalog";

const INITIAL_STATE: CatalogActionState = { error: null, message: null };

export function ProductLifecycleActions({
  productId,
  archived,
  dictionary,
}: {
  productId: string;
  archived: boolean;
  dictionary: Dictionary;
}) {
  const [state, formAction, pending] = useActionState(archived ? restoreProduct : archiveProduct, INITIAL_STATE);

  return (
    <form action={formAction}>
      <input type="hidden" name="product_id" value={productId} />
      <button type="submit" disabled={pending} className="text-sm font-bold text-emerald-700 hover:text-emerald-900 disabled:opacity-50">
        {archived ? dictionary.catalog.restoreProduct : dictionary.catalog.archiveProduct}
      </button>
      {state.error ? <p className="mt-1 text-xs text-red-700">{state.error}</p> : null}
      {state.message ? <p className="mt-1 text-xs text-emerald-700">{state.message}</p> : null}
    </form>
  );
}
