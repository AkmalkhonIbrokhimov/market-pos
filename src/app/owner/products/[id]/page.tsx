import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";

import { OwnerHeader } from "@/components/owner-header";
import { ProductLifecycleActions } from "@/components/product-lifecycle-actions";
import { ROUTES, getOwnerProductEditRoute, getOwnerProductStockIncomeRoute } from "@/constants/routes";
import { getDictionary, getLocale } from "@/i18n/server";
import { requireOwnerManager } from "@/lib/auth/guards";
import { getProduct } from "@/services/products";

export const metadata: Metadata = { title: "Product details" };
export const dynamic = "force-dynamic";

function Detail({ label, value }: { label: string; value: string | number | null }) {
  return <div className="border-b border-slate-200 py-3"><dt className="text-xs font-bold uppercase text-slate-500">{label}</dt><dd className="mt-1 text-sm font-semibold text-slate-900">{value ?? "-"}</dd></div>;
}

export default async function ProductDetailsPage({ params }: { params: Promise<{ id: string }> }) {
  const [currentUser, dictionary, locale, { id }] = await Promise.all([requireOwnerManager(), getDictionary(), getLocale(), params]);
  const organizationId = currentUser.profile.organizationId;
  if (!organizationId) notFound();
  const product = await getProduct(organizationId, id);
  if (!product) notFound();
  const lowStock = product.currentQuantity <= product.minQuantity;
  const number = new Intl.NumberFormat(locale, { maximumFractionDigits: 3 });
  const price = new Intl.NumberFormat(locale, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

  return <div className="min-h-screen bg-slate-50">
    <OwnerHeader dictionary={dictionary} />
    <main className="mx-auto w-full max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
      <div className="flex flex-wrap items-end justify-between gap-5 border-b border-slate-200 pb-6">
        <div><p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.productDetails}</p><h1 className="mt-2 text-3xl font-bold text-slate-950">{product.name}</h1><p className="mt-2 text-sm text-slate-600">{product.categoryName ?? dictionary.catalog.uncategorized}</p></div>
        <div className="flex flex-wrap items-center gap-3"><Link href={getOwnerProductEditRoute(product.id)} className="bg-emerald-700 px-4 py-2.5 text-sm font-bold text-white">{dictionary.catalog.editProductTitle}</Link><Link href={getOwnerProductStockIncomeRoute(product.id)} className="border border-slate-300 bg-white px-4 py-2.5 text-sm font-bold text-slate-700">{dictionary.catalog.addStockIncome}</Link><ProductLifecycleActions productId={product.id} archived={Boolean(product.archivedAt)} dictionary={dictionary} /></div>
      </div>

      {lowStock ? <p className="mt-6 border-l-4 border-red-500 bg-red-50 p-4 text-sm font-semibold text-red-900">{product.currentQuantity <= 0 ? dictionary.catalog.outOfStock : dictionary.catalog.lowStock}: {number.format(product.currentQuantity)} {product.unitName}</p> : null}

      <div className="mt-6 grid gap-8 lg:grid-cols-[18rem_minmax(0,1fr)]">
        <div><div className="relative aspect-square overflow-hidden border border-slate-200 bg-white">{product.imageUrl ? <Image src={product.imageUrl} alt={product.name} fill unoptimized className="object-contain" /> : <div className="flex size-full items-center justify-center p-5 text-center text-sm text-slate-500">{dictionary.catalog.imagePlaceholder}</div>}</div><p className="mt-2 text-xs text-slate-500">{dictionary.catalog.imageUploadLater}</p></div>
        <div className="grid gap-x-8 md:grid-cols-2">
          <dl><Detail label={dictionary.catalog.sku} value={product.sku} /><Detail label={dictionary.common.barcode} value={product.barcode} /><Detail label={dictionary.catalog.brand} value={product.brandName} /><Detail label={dictionary.catalog.productType} value={product.productTypeName} /><Detail label={dictionary.catalog.unit} value={product.unitName} /><Detail label={dictionary.common.salePrice} value={price.format(product.salePrice)} /></dl>
          <dl><Detail label={dictionary.common.currentQuantity} value={`${number.format(product.currentQuantity)} ${product.unitName}`} /><Detail label={dictionary.common.minimumQuantity} value={number.format(product.minQuantity)} /><Detail label={dictionary.catalog.weight} value={product.weight === null ? null : `${number.format(product.weight)} ${product.weightUnit ?? ""}`} /><Detail label={dictionary.catalog.volume} value={product.volume === null ? null : `${number.format(product.volume)} ${product.volumeUnit ?? ""}`} /><Detail label={dictionary.catalog.size} value={product.sizeText} /><Detail label={dictionary.catalog.color} value={product.color} /><Detail label={dictionary.catalog.packageSize} value={product.packageSize} /><Detail label={dictionary.common.status} value={product.archivedAt ? dictionary.catalog.archived : product.status === "active" ? dictionary.common.active : dictionary.common.inactive} /></dl>
        </div>
      </div>
      <section className="mt-8 border-t border-slate-200 pt-6"><h2 className="text-lg font-bold text-slate-950">{dictionary.catalog.description}</h2><p className="mt-3 whitespace-pre-wrap text-sm leading-6 text-slate-700">{product.description ?? "-"}</p></section>
      <div className="mt-8 flex flex-wrap gap-4 border-t border-slate-200 pt-5"><Link href={ROUTES.OWNER_STOCK_MOVEMENTS} className="font-bold text-emerald-700">{dictionary.catalog.viewMovementHistory}</Link><Link href={ROUTES.OWNER_PRODUCTS} className="font-semibold text-slate-600">{dictionary.common.back}</Link></div>
    </main>
  </div>;
}
