import { CategoryLifecycleActions } from "@/components/category-lifecycle-actions";
import { getStatusLabel } from "@/i18n/dictionaries";
import type { Dictionary } from "@/i18n/types";
import type { Category } from "@/types/catalog";

function CategoryBranch({
  categories,
  dictionary,
  depth = 0,
  parentName,
}: {
  categories: Category[];
  dictionary: Dictionary;
  depth?: number;
  parentName?: string;
}) {
  return categories.map((category) => (
    <div key={category.id}>
      <div
        className={`grid gap-4 border-t border-slate-200 px-4 py-4 lg:grid-cols-[minmax(0,1fr)_9rem_minmax(16rem,auto)] lg:items-center ${
          category.archivedAt ? "bg-slate-100" : "bg-white"
        }`}
      >
        <div style={{ paddingLeft: `${Math.min(depth, 5) * 1.25}rem` }}>
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="font-bold text-slate-950">{category.name}</h3>
            {depth > 0 ? (
              <span className="border border-sky-200 bg-sky-50 px-2 py-0.5 text-xs font-semibold text-sky-800">
                {dictionary.catalog.subcategory}
              </span>
            ) : null}
            {category.archivedAt ? (
              <span className="border border-slate-300 bg-slate-200 px-2 py-0.5 text-xs font-semibold text-slate-700">
                {dictionary.catalog.archived}
              </span>
            ) : null}
          </div>
          {parentName ? (
            <p className="mt-1 text-xs text-slate-500">
              {dictionary.catalog.parentCategory}: {parentName}
            </p>
          ) : null}
          {category.description ? <p className="mt-2 text-sm text-slate-600">{category.description}</p> : null}
          {category.children.length > 0 ? (
            <p className="mt-2 text-xs font-medium text-slate-500">{dictionary.catalog.hasSubcategories}</p>
          ) : null}
          {category.directProductCount > 0 ? (
            <p className="mt-2 text-xs text-amber-800">
              {dictionary.catalog.categoryHasProducts}. {dictionary.catalog.archiveKeepsHistory}
            </p>
          ) : null}
        </div>
        <div className="text-sm text-slate-600">
          <span className={category.status === "active" && !category.archivedAt ? "font-semibold text-emerald-700" : "font-semibold text-slate-500"}>
            {category.archivedAt ? dictionary.catalog.archived : getStatusLabel(category.status, dictionary)}
          </span>
          <p className="mt-1 text-xs text-slate-500">
            {dictionary.catalog.directProducts}: {category.directProductCount}
          </p>
        </div>
        <CategoryLifecycleActions category={category} dictionary={dictionary} />
      </div>
      {category.children.length > 0 ? (
        <CategoryBranch
          categories={category.children}
          dictionary={dictionary}
          depth={depth + 1}
          parentName={category.name}
        />
      ) : null}
    </div>
  ));
}

export function CategoryTree({ categories, dictionary }: { categories: Category[]; dictionary: Dictionary }) {
  return (
    <section aria-labelledby="category-tree-title" className="overflow-hidden border border-slate-200">
      <div className="flex flex-wrap items-center justify-between gap-3 bg-slate-100 px-4 py-3">
        <h2 id="category-tree-title" className="text-sm font-bold uppercase text-slate-700">
          {dictionary.catalog.categoryTree}
        </h2>
        <span className="text-xs font-medium text-slate-500">{dictionary.catalog.productCount}</span>
      </div>
      <CategoryBranch categories={categories} dictionary={dictionary} />
    </section>
  );
}
