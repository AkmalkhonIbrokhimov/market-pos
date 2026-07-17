import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { CategoryForm } from "@/components/category-form";
import { OwnerHeader } from "@/components/owner-header";
import { getDictionary } from "@/i18n/server";
import { requireOwnerManager } from "@/lib/auth/guards";
import { getCategory, listCategoryOptions } from "@/services/categories";

export const metadata: Metadata = { title: "Edit category" };
export const dynamic = "force-dynamic";

type EditCategoryPageProps = {
  params: Promise<{ id: string }>;
};

export default async function EditCategoryPage({ params }: EditCategoryPageProps) {
  const [currentUser, dictionary, { id }] = await Promise.all([
    requireOwnerManager(),
    getDictionary(),
    params,
  ]);
  const organizationId = currentUser.profile.organizationId;

  if (!organizationId) {
    notFound();
  }

  const [category, categoryOptions] = await Promise.all([
    getCategory(organizationId, id),
    listCategoryOptions(organizationId, {
      includeInactive: true,
      excludeBranchId: id,
    }),
  ]);

  if (!category) {
    notFound();
  }

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="border-b border-slate-200 pb-6">
          <p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.eyebrow}</p>
          <h1 className="mt-2 text-3xl font-bold text-slate-950">{dictionary.catalog.editCategory}</h1>
          <p className="mt-2 text-sm text-slate-600">{dictionary.catalog.editCategoryDescription}</p>
        </div>
        <div className="mt-6">
          <CategoryForm categories={categoryOptions} category={category} dictionary={dictionary} />
        </div>
      </main>
    </div>
  );
}
