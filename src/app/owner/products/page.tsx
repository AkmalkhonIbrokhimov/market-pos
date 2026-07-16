import type { Metadata } from "next";
import Link from "next/link";

import { OwnerHeader } from "@/components/owner-header";
import { ROUTES, getOwnerProductEditRoute } from "@/constants/routes";
import { requireOwnerManager } from "@/lib/auth/guards";
import { listProducts } from "@/services/products";

export const metadata: Metadata = { title: "Products" };
export const dynamic = "force-dynamic";

type ProductsPageProps = {
  searchParams: Promise<{ search?: string | string[] }>;
};

function formatQuantity(value: number): string {
  return new Intl.NumberFormat("en-US", { maximumFractionDigits: 3 }).format(value);
}

function formatPrice(value: number): string {
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

export default async function ProductsPage({ searchParams }: ProductsPageProps) {
  const currentUser = await requireOwnerManager();
  const organizationId = currentUser.profile.organizationId;
  const rawSearch = (await searchParams).search;
  const search = (Array.isArray(rawSearch) ? rawSearch[0] : rawSearch ?? "").trim();
  const products = organizationId ? await listProducts(organizationId) : [];
  const normalizedSearch = search.toLocaleLowerCase();
  const visibleProducts = normalizedSearch
    ? products.filter(
        (product) =>
          product.name.toLocaleLowerCase().includes(normalizedSearch) ||
          product.barcode?.toLocaleLowerCase().includes(normalizedSearch),
      )
    : products;

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader />
      <main className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-5 border-b border-slate-200 pb-6 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase text-emerald-700">Catalog</p>
            <h1 className="mt-2 text-3xl font-bold text-slate-950">Products</h1>
            <p className="mt-2 text-sm text-slate-600">
              Manage product details while stock quantities remain controlled by stock operations.
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link
              href={ROUTES.OWNER_CATEGORIES}
              className="border border-slate-300 bg-white px-4 py-2.5 text-sm font-bold text-slate-700 hover:border-slate-400 hover:text-slate-950"
            >
              Categories
            </Link>
            <Link
              href={ROUTES.OWNER_NEW_PRODUCT}
              className="bg-emerald-700 px-4 py-2.5 text-sm font-bold text-white hover:bg-emerald-800"
            >
              Add product
            </Link>
          </div>
        </div>

        {!organizationId ? (
          <p className="mt-6 border-l-4 border-amber-500 bg-amber-50 p-4 text-sm text-amber-900">
            Your user profile is not assigned to an organization.
          </p>
        ) : null}

        <form className="mt-6 flex max-w-xl gap-3" role="search">
          <label htmlFor="product-search" className="sr-only">
            Search by product name or barcode
          </label>
          <input
            id="product-search"
            name="search"
            defaultValue={search}
            placeholder="Search by name or barcode"
            className="min-w-0 flex-1 border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          />
          <button
            type="submit"
            className="bg-slate-900 px-4 py-2.5 text-sm font-bold text-white hover:bg-slate-800"
          >
            Search
          </button>
        </form>

        <div className="mt-6 overflow-x-auto border border-slate-200 bg-white">
          <table className="min-w-[1050px] w-full border-collapse text-left text-sm">
            <thead className="bg-slate-100 text-xs uppercase text-slate-600">
              <tr>
                <th scope="col" className="px-4 py-3 font-bold">Product</th>
                <th scope="col" className="px-4 py-3 font-bold">Category</th>
                <th scope="col" className="px-4 py-3 font-bold">Barcode</th>
                <th scope="col" className="px-4 py-3 font-bold">Unit</th>
                <th scope="col" className="px-4 py-3 text-right font-bold">Sale price</th>
                <th scope="col" className="px-4 py-3 text-right font-bold">Current qty.</th>
                <th scope="col" className="px-4 py-3 text-right font-bold">Min qty.</th>
                <th scope="col" className="px-4 py-3 font-bold">Status</th>
                <th scope="col" className="px-4 py-3 text-right font-bold">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {visibleProducts.map((product) => (
                <tr key={product.id} className="text-slate-700 hover:bg-slate-50">
                  <th scope="row" className="px-4 py-3 font-semibold text-slate-950">
                    {product.name}
                  </th>
                  <td className="px-4 py-3">{product.categoryName ?? "Uncategorized"}</td>
                  <td className="px-4 py-3 font-mono text-xs">{product.barcode ?? "-"}</td>
                  <td className="px-4 py-3">{product.unit}</td>
                  <td className="px-4 py-3 text-right tabular-nums">{formatPrice(product.salePrice)}</td>
                  <td className="px-4 py-3 text-right tabular-nums">
                    {formatQuantity(product.currentQuantity)}
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums">
                    {formatQuantity(product.minQuantity)}
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={
                        product.status === "active"
                          ? "font-semibold text-emerald-700"
                          : "font-semibold text-slate-500"
                      }
                    >
                      {product.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right">
                    <Link
                      href={getOwnerProductEditRoute(product.id)}
                      className="font-bold text-emerald-700 hover:text-emerald-800"
                    >
                      Edit
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {visibleProducts.length === 0 ? (
            <p className="border-t border-slate-200 px-4 py-10 text-center text-sm text-slate-500">
              {search ? "No products match this search." : "No products have been added yet."}
            </p>
          ) : null}
        </div>
      </main>
    </div>
  );
}
