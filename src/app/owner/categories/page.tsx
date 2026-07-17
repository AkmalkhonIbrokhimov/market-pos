import type { Metadata } from "next";
import Link from "next/link";

import { CategoryForm } from "@/components/category-form";
import { CategoryTree } from "@/components/category-tree";
import { OwnerHeader } from "@/components/owner-header";
import { getDictionary } from "@/i18n/server";
import { requireOwnerManager } from "@/lib/auth/guards";
import { listCategoryOptions, listCategoryTree } from "@/services/categories";

export const metadata: Metadata = { title: "Categories" };
export const dynamic = "force-dynamic";

type CategoriesPageProps = {
  searchParams: Promise<{ parent_id?: string }>;
};

export default async function CategoriesPage({ searchParams }: CategoriesPageProps) {
  const [currentUser, dictionary, query] = await Promise.all([
    requireOwnerManager(),
    getDictionary(),
    searchParams,
  ]);
  const organizationId = currentUser.profile.organizationId;
  const [categoryTree, categoryOptions] = organizationId
    ? await Promise.all([
        listCategoryTree(organizationId),
        listCategoryOptions(organizationId, { includeInactive: true }),
      ])
    : [[], []];
  const defaultParentId = categoryOptions.some((category) => category.id === query.parent_id)
    ? query.parent_id
    : null;

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-wrap items-end justify-between gap-4 border-b border-slate-200 pb-6">
          <div>
            <p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.eyebrow}</p>
            <h1 className="mt-2 text-3xl font-bold text-slate-950">{dictionary.catalog.categories}</h1>
            <p className="mt-2 max-w-3xl text-sm text-slate-600">{dictionary.catalog.categoriesDescription}</p>
          </div>
          <Link href="#category-form" className="bg-emerald-700 px-4 py-2.5 text-sm font-bold text-white hover:bg-emerald-800">
            {dictionary.catalog.addCategory}
          </Link>
        </div>

        {!organizationId ? (
          <p className="mt-6 border-l-4 border-amber-500 bg-amber-50 p-4 text-sm text-amber-900">
            {dictionary.catalog.noOrganization}
          </p>
        ) : null}

        <div className="mt-6">
          {categoryTree.length > 0 ? (
            <CategoryTree categories={categoryTree} dictionary={dictionary} />
          ) : (
            <p className="border border-slate-200 bg-white px-4 py-10 text-center text-sm text-slate-500">
              {dictionary.catalog.noCategories}
            </p>
          )}
        </div>

        <div className="mt-6">
          <CategoryForm
            categories={categoryOptions}
            defaultParentId={defaultParentId}
            dictionary={dictionary}
          />
        </div>
      </main>
    </div>
  );
}
