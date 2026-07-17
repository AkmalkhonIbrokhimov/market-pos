import Link from "next/link";

import { OwnerHeader } from "@/components/owner-header";
import { ProductLifecycleActions } from "@/components/product-lifecycle-actions";
import { ROUTES, getOwnerProductRoute } from "@/constants/routes";
import { getDictionary } from "@/i18n/server";
import { requireOwnerManager } from "@/lib/auth/guards";
import { listProducts } from "@/services/products";

export default async function ProductArchivePage() {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const products = organizationId ? (await listProducts(organizationId)).filter((item) => item.archivedAt) : [];

  return <div className="min-h-screen bg-slate-50"><OwnerHeader dictionary={dictionary} /><main className="mx-auto w-full max-w-6xl px-4 py-8 sm:px-6 lg:px-8"><div className="flex flex-wrap items-end justify-between gap-4 border-b border-slate-200 pb-6"><div><p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.eyebrow}</p><h1 className="mt-2 text-3xl font-bold text-slate-950">{dictionary.catalog.productArchive}</h1><p className="mt-2 text-sm text-slate-600">{dictionary.catalog.productArchiveDescription}</p></div><Link href={ROUTES.OWNER_PRODUCTS} className="border border-slate-300 bg-white px-4 py-2.5 text-sm font-bold text-slate-700">{dictionary.catalog.allProducts}</Link></div><div className="mt-6 divide-y divide-slate-200 border border-slate-200 bg-white">{products.map((product) => <div key={product.id} className="flex flex-wrap items-center justify-between gap-4 px-4 py-4"><div><Link href={getOwnerProductRoute(product.id)} className="font-bold text-slate-950 hover:text-emerald-700">{product.name}</Link><p className="mt-1 text-xs text-slate-500">{dictionary.catalog.sku}: {product.sku ?? "-"} · {product.categoryName ?? dictionary.catalog.uncategorized}</p></div><ProductLifecycleActions productId={product.id} archived dictionary={dictionary} /></div>)}{products.length === 0 ? <p className="px-4 py-10 text-center text-sm text-slate-500">{dictionary.catalog.noArchivedProducts}</p> : null}</div></main></div>;
}
