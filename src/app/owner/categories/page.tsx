import type { Metadata } from "next";

import { CategoryForm } from "@/components/category-form";
import { OwnerHeader } from "@/components/owner-header";
import { requireOwnerManager } from "@/lib/auth/guards";
import { getStatusLabel } from "@/i18n/dictionaries";
import { getDictionary } from "@/i18n/server";
import { listCategories } from "@/services/categories";

export const metadata: Metadata = { title: "Categories" };
export const dynamic = "force-dynamic";

export default async function CategoriesPage() {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const categories = organizationId ? await listCategories(organizationId) : [];

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="border-b border-slate-200 pb-6">
          <p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.eyebrow}</p>
          <h1 className="mt-2 text-3xl font-bold text-slate-950">{dictionary.catalog.categories}</h1>
          <p className="mt-2 text-sm text-slate-600">
            {dictionary.catalog.categoriesDescription}
          </p>
        </div>

        <div className="mt-6">
          <CategoryForm dictionary={dictionary} />
        </div>

        {!organizationId ? (
          <p className="mt-6 border-l-4 border-amber-500 bg-amber-50 p-4 text-sm text-amber-900">
            {dictionary.catalog.noOrganization}
          </p>
        ) : null}

        <div className="mt-6 overflow-hidden border border-slate-200 bg-white">
          <table className="w-full border-collapse text-left text-sm">
            <thead className="bg-slate-100 text-xs uppercase text-slate-600">
              <tr>
                <th scope="col" className="px-4 py-3 font-bold">{dictionary.common.category}</th>
                <th scope="col" className="px-4 py-3 text-right font-bold">{dictionary.common.status}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {categories.map((category) => (
                <tr key={category.id} className="text-slate-700">
                  <th scope="row" className="px-4 py-3 font-semibold text-slate-950">
                    {category.name}
                  </th>
                  <td className="px-4 py-3 text-right">
                    <span
                      className={
                        category.status === "active"
                          ? "font-semibold text-emerald-700"
                          : "font-semibold text-slate-500"
                      }
                    >
                      {getStatusLabel(category.status, dictionary)}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {categories.length === 0 ? (
            <p className="border-t border-slate-200 px-4 py-10 text-center text-sm text-slate-500">
              {dictionary.catalog.noCategories}
            </p>
          ) : null}
        </div>
      </main>
    </div>
  );
}
