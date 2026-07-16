import type { Metadata } from "next";

import { OwnerHeader } from "@/components/owner-header";
import { ProductForm } from "@/components/product-form";
import { requireOwnerManager } from "@/lib/auth/guards";
import { getDictionary } from "@/i18n/server";
import { listCategories } from "@/services/categories";

export const metadata: Metadata = { title: "Add product" };
export const dynamic = "force-dynamic";

export default async function NewProductPage() {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const categories = organizationId ? await listCategories(organizationId) : [];

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="border-b border-slate-200 pb-6">
          <p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.eyebrow}</p>
          <h1 className="mt-2 text-3xl font-bold text-slate-950">{dictionary.catalog.addProductTitle}</h1>
          <p className="mt-2 text-sm text-slate-600">{dictionary.catalog.addProductDescription}</p>
        </div>
        <div className="mt-6">
          <ProductForm categories={categories} dictionary={dictionary} />
        </div>
      </main>
    </div>
  );
}
