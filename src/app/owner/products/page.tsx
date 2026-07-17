import type { Metadata } from "next";
import Link from "next/link";

import { OwnerHeader } from "@/components/owner-header";
import { ProductLifecycleActions } from "@/components/product-lifecycle-actions";
import {
  ROUTES,
  getOwnerProductEditRoute,
  getOwnerProductRoute,
  getOwnerProductStockIncomeRoute,
} from "@/constants/routes";
import { getDictionary, getLocale } from "@/i18n/server";
import { requireOwnerManager } from "@/lib/auth/guards";
import { listBrands } from "@/services/brands";
import { listCategoryOptions } from "@/services/categories";
import { listProducts } from "@/services/products";

export const metadata: Metadata = { title: "Products" };
export const dynamic = "force-dynamic";

type ProductsPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

function valueOf(value: string | string[] | undefined): string {
  return (Array.isArray(value) ? value[0] : value ?? "").trim();
}

export default async function ProductsPage({ searchParams }: ProductsPageProps) {
  const [currentUser, dictionary, locale, query] = await Promise.all([
    requireOwnerManager(),
    getDictionary(),
    getLocale(),
    searchParams,
  ]);
  const organizationId = currentUser.profile.organizationId;
  const [products, categories, brands] = organizationId
    ? await Promise.all([
        listProducts(organizationId),
        listCategoryOptions(organizationId, { includeInactive: true, includeArchived: true }),
        listBrands(organizationId),
      ])
    : [[], [], []];
  const search = valueOf(query.search).toLocaleLowerCase();
  const category = valueOf(query.category);
  const brand = valueOf(query.brand);
  const status = valueOf(query.status) || "all";
  const archive = valueOf(query.archive) || "current";
  const visibleProducts = products.filter((product) => {
    const matchesSearch = !search || product.name.toLocaleLowerCase().includes(search) || product.sku?.toLocaleLowerCase().includes(search) || product.barcode?.toLocaleLowerCase().includes(search);
    const matchesArchive = archive === "all" || (archive === "archived" ? Boolean(product.archivedAt) : !product.archivedAt);
    return matchesSearch && (!category || product.categoryId === category) && (!brand || product.brandId === brand) && (status === "all" || product.status === status) && matchesArchive;
  });
  const number = new Intl.NumberFormat(locale, { maximumFractionDigits: 3 });
  const price = new Intl.NumberFormat(locale, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-wrap items-end justify-between gap-5 border-b border-slate-200 pb-6">
          <div><p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.eyebrow}</p><h1 className="mt-2 text-3xl font-bold text-slate-950">{dictionary.catalog.products}</h1><p className="mt-2 text-sm text-slate-600">{dictionary.catalog.productsDescription}</p></div>
          <div className="flex flex-wrap gap-2">
            <Link href={ROUTES.OWNER_CATALOG_IMPORT} className="border border-slate-300 bg-white px-3 py-2 text-sm font-semibold text-slate-700">{dictionary.catalog.importExcel}</Link>
            <Link href={ROUTES.OWNER_CATALOG_EXPORT} className="border border-slate-300 bg-white px-3 py-2 text-sm font-semibold text-slate-700">{dictionary.catalog.exportExcel}</Link>
            <Link href={ROUTES.OWNER_CATALOG_PRINT_PRICE_TAGS} className="border border-slate-300 bg-white px-3 py-2 text-sm font-semibold text-slate-700">{dictionary.catalog.printPriceTags}</Link>
            <Link href={ROUTES.OWNER_CATALOG_PRINT_BARCODES} className="border border-slate-300 bg-white px-3 py-2 text-sm font-semibold text-slate-700">{dictionary.catalog.printBarcodes}</Link>
            <Link href={ROUTES.OWNER_NEW_PRODUCT} className="bg-emerald-700 px-4 py-2 text-sm font-bold text-white">{dictionary.catalog.addProduct}</Link>
          </div>
        </div>

        <form className="mt-6 grid gap-3 border border-slate-200 bg-white p-4 sm:grid-cols-2 lg:grid-cols-[minmax(14rem,1fr)_repeat(4,minmax(10rem,auto))_auto]" role="search">
          <input name="search" defaultValue={valueOf(query.search)} placeholder={dictionary.catalog.searchProducts2} className="border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-600" />
          <select name="category" defaultValue={category} className="border border-slate-300 bg-white px-3 py-2.5 text-sm"><option value="">{dictionary.catalog.filterByCategory}</option>{categories.map((item) => <option key={item.id} value={item.id}>{`${"— ".repeat(item.depth)}${item.name}`}</option>)}</select>
          <select name="brand" defaultValue={brand} className="border border-slate-300 bg-white px-3 py-2.5 text-sm"><option value="">{dictionary.catalog.filterByBrand}</option>{brands.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select>
          <select name="status" defaultValue={status} className="border border-slate-300 bg-white px-3 py-2.5 text-sm"><option value="all">{dictionary.catalog.allStatuses}</option><option value="active">{dictionary.common.active}</option><option value="inactive">{dictionary.common.inactive}</option></select>
          <select name="archive" defaultValue={archive} className="border border-slate-300 bg-white px-3 py-2.5 text-sm"><option value="current">{dictionary.catalog.currentProducts}</option><option value="archived">{dictionary.catalog.archivedProducts}</option><option value="all">{dictionary.catalog.allProducts}</option></select>
          <button type="submit" className="bg-slate-900 px-4 py-2.5 text-sm font-bold text-white">{dictionary.common.search}</button>
        </form>

        <div className="mt-6 overflow-x-auto border border-slate-200 bg-white">
          <table className="w-full min-w-[1150px] border-collapse text-left text-sm">
            <thead className="bg-slate-100 text-xs uppercase text-slate-600"><tr><th className="px-4 py-3">{dictionary.catalog.product}</th><th className="px-4 py-3">{dictionary.common.category}</th><th className="px-4 py-3">{dictionary.catalog.brand}</th><th className="px-4 py-3 text-right">{dictionary.common.salePrice}</th><th className="px-4 py-3 text-right">{dictionary.catalog.stock}</th><th className="px-4 py-3">{dictionary.common.status}</th><th className="px-4 py-3 text-right">{dictionary.common.action}</th></tr></thead>
            <tbody className="divide-y divide-slate-200">
              {visibleProducts.map((product) => {
                const lowStock = product.currentQuantity <= product.minQuantity;
                return <tr key={product.id} className={product.archivedAt ? "bg-slate-100 text-slate-500" : "text-slate-700 hover:bg-slate-50"}>
                  <th className="px-4 py-3"><Link href={getOwnerProductRoute(product.id)} className="font-bold text-slate-950 hover:text-emerald-700">{product.name}</Link><p className="mt-1 font-mono text-xs font-normal text-slate-500">{dictionary.catalog.sku}: {product.sku ?? "-"} · {dictionary.common.barcode}: {product.barcode ?? "-"}</p></th>
                  <td className="px-4 py-3">{product.categoryName ?? dictionary.catalog.uncategorized}</td>
                  <td className="px-4 py-3">{product.brandName ?? "-"}</td>
                  <td className="px-4 py-3 text-right tabular-nums">{price.format(product.salePrice)}</td>
                  <td className="px-4 py-3 text-right"><span className={lowStock ? "font-bold text-red-700" : "font-bold text-emerald-700"}>{number.format(product.currentQuantity)} {product.unitName}</span><p className="mt-1 text-xs">{product.currentQuantity <= 0 ? dictionary.catalog.outOfStock : lowStock ? dictionary.catalog.lowStock : dictionary.catalog.inStock}</p></td>
                  <td className="px-4 py-3">{product.archivedAt ? dictionary.catalog.archived : product.status === "active" ? dictionary.common.active : dictionary.common.inactive}</td>
                  <td className="px-4 py-3"><div className="flex flex-wrap justify-end gap-x-3 gap-y-2"><Link href={getOwnerProductRoute(product.id)} className="font-bold text-emerald-700">{dictionary.catalog.viewProduct}</Link><Link href={getOwnerProductEditRoute(product.id)} className="font-bold text-slate-600">{dictionary.common.edit}</Link><Link href={getOwnerProductStockIncomeRoute(product.id)} className="font-bold text-slate-600">{dictionary.catalog.addStockIncome}</Link><ProductLifecycleActions productId={product.id} archived={Boolean(product.archivedAt)} dictionary={dictionary} /><span title={dictionary.catalog.productOperationsArchiveOnly} className="cursor-not-allowed font-semibold text-slate-400">{dictionary.catalog.deleteProduct}</span></div></td>
                </tr>;
              })}
            </tbody>
          </table>
          {visibleProducts.length === 0 ? <p className="px-4 py-10 text-center text-sm text-slate-500">{valueOf(query.search) ? dictionary.catalog.noSearchResults : dictionary.catalog.noProducts}</p> : null}
        </div>
      </main>
    </div>
  );
}
