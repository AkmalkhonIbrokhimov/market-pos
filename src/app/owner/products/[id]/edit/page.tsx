import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { OwnerHeader } from "@/components/owner-header";
import { ProductForm } from "@/components/product-form";
import { requireOwnerManager } from "@/lib/auth/guards";
import { getDictionary } from "@/i18n/server";
import { listCategoryOptions } from "@/services/categories";
import { listBrands } from "@/services/brands";
import { listProductTypes } from "@/services/product-types";
import { getProduct } from "@/services/products";
import { listUnits } from "@/services/units";

export const metadata: Metadata = { title: "Edit product" };
export const dynamic = "force-dynamic";

type EditProductPageProps = {
  params: Promise<{ id: string }>;
};

export default async function EditProductPage({ params }: EditProductPageProps) {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const { id } = await params;

  if (!organizationId) {
    notFound();
  }

  const [product, categories, brands, units, productTypes] = await Promise.all([
    getProduct(organizationId, id),
    listCategoryOptions(organizationId, { includeInactive: true, includeArchived: true }),
    listBrands(organizationId),
    listUnits(organizationId),
    listProductTypes(organizationId),
  ]);

  if (!product) {
    notFound();
  }

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="border-b border-slate-200 pb-6">
          <p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.eyebrow}</p>
          <h1 className="mt-2 text-3xl font-bold text-slate-950">{dictionary.catalog.editProductTitle}</h1>
          <p className="mt-2 text-sm text-slate-600">
            {dictionary.catalog.editProductDescription}
          </p>
        </div>
        <div className="mt-6">
          <ProductForm categories={categories} brands={brands} units={units} productTypes={productTypes} dictionary={dictionary} product={product} />
        </div>
      </main>
    </div>
  );
}
