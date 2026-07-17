import type { Metadata } from "next";

import { OwnerHeader } from "@/components/owner-header";
import { ProductForm } from "@/components/product-form";
import { requireOwnerManager } from "@/lib/auth/guards";
import { getDictionary } from "@/i18n/server";
import { listCategoryOptions } from "@/services/categories";
import { listBrands } from "@/services/brands";
import { listProductTypes } from "@/services/product-types";
import { listUnits } from "@/services/units";

export const metadata: Metadata = { title: "Add product" };
export const dynamic = "force-dynamic";

export default async function NewProductPage() {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const [categories, brands, units, productTypes] = organizationId
    ? await Promise.all([
        listCategoryOptions(organizationId),
        listBrands(organizationId, false),
        listUnits(organizationId, false),
        listProductTypes(organizationId, false),
      ])
    : [[], [], [], []];

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
          <ProductForm categories={categories} brands={brands} units={units} productTypes={productTypes} dictionary={dictionary} />
        </div>
      </main>
    </div>
  );
}
