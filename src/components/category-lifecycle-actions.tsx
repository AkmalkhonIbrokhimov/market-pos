"use client";

import Link from "next/link";
import { useActionState } from "react";

import { getOwnerAddSubcategoryRoute, getOwnerCategoryEditRoute } from "@/constants/routes";
import type { Dictionary } from "@/i18n/types";
import {
  archiveCategory,
  deactivateCategory,
  restoreCategory,
} from "@/lib/categories/actions";
import type { CatalogActionState, Category } from "@/types/catalog";

const INITIAL_STATE: CatalogActionState = { error: null, message: null };

type LifecycleAction = (
  previousState: CatalogActionState,
  formData: FormData,
) => Promise<CatalogActionState>;

function CategoryActionForm({
  action,
  categoryId,
  label,
  tone = "neutral",
}: {
  action: LifecycleAction;
  categoryId: string;
  label: string;
  tone?: "neutral" | "danger";
}) {
  const [state, formAction, isPending] = useActionState(action, INITIAL_STATE);

  return (
    <form action={formAction} className="contents">
      <input type="hidden" name="category_id" value={categoryId} />
      <button
        type="submit"
        disabled={isPending}
        className={
          tone === "danger"
            ? "text-sm font-semibold text-red-700 hover:text-red-900 disabled:opacity-50"
            : "text-sm font-semibold text-slate-600 hover:text-slate-950 disabled:opacity-50"
        }
      >
        {label}
      </button>
      {state.error ? <span className="basis-full text-xs font-medium text-red-700">{state.error}</span> : null}
      {state.message ? <span className="basis-full text-xs font-medium text-emerald-700">{state.message}</span> : null}
    </form>
  );
}

export function CategoryLifecycleActions({
  category,
  dictionary,
}: {
  category: Category;
  dictionary: Dictionary;
}) {
  return (
    <div className="flex flex-wrap items-center justify-start gap-x-4 gap-y-2 lg:justify-end">
      {!category.archivedAt ? (
        <Link
          href={getOwnerAddSubcategoryRoute(category.id)}
          className="text-sm font-semibold text-emerald-700 hover:text-emerald-900"
        >
          {dictionary.catalog.addSubcategory}
        </Link>
      ) : null}
      <Link
        href={getOwnerCategoryEditRoute(category.id)}
        className="text-sm font-semibold text-slate-600 hover:text-slate-950"
      >
        {dictionary.common.edit}
      </Link>
      {!category.archivedAt && category.status === "active" ? (
        <CategoryActionForm
          action={deactivateCategory}
          categoryId={category.id}
          label={dictionary.catalog.deactivateCategory}
        />
      ) : null}
      {category.archivedAt ? (
        <CategoryActionForm
          action={restoreCategory}
          categoryId={category.id}
          label={dictionary.catalog.restoreCategory}
        />
      ) : (
        <CategoryActionForm
          action={archiveCategory}
          categoryId={category.id}
          label={dictionary.catalog.archiveCategory}
          tone="danger"
        />
      )}
    </div>
  );
}
