import { CatalogReferenceManager, type ReferenceManagerItem } from "@/components/catalog-reference-manager";
import { OwnerHeader } from "@/components/owner-header";
import { getDictionary } from "@/i18n/server";
import { requireOwnerManager } from "@/lib/auth/guards";
import type { ReferenceKind } from "@/lib/catalog-reference/helpers";
import { listBrands } from "@/services/brands";
import { listProductTypes } from "@/services/product-types";
import { listUnits } from "@/services/units";

export async function CatalogReferencePage({ kind }: { kind: ReferenceKind }) {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  let items: ReferenceManagerItem[] = [];

  if (organizationId && kind === "brand") {
    items = (await listBrands(organizationId)).map((item) => ({ ...item, detail: null }));
  } else if (organizationId && kind === "unit") {
    items = (await listUnits(organizationId)).map((item) => ({ ...item, detail: item.shortName, description: null }));
  } else if (organizationId) {
    items = (await listProductTypes(organizationId)).map((item) => ({ ...item, detail: item.code }));
  }

  const title = kind === "brand" ? dictionary.catalog.brands : kind === "unit" ? dictionary.catalog.units : dictionary.catalog.productTypes;
  const description = kind === "brand" ? dictionary.catalog.brandsDescription : kind === "unit" ? dictionary.catalog.unitsDescription : dictionary.catalog.productTypesDescription;

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="border-b border-slate-200 pb-6">
          <p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.catalog.eyebrow}</p>
          <h1 className="mt-2 text-3xl font-bold text-slate-950">{title}</h1>
          <p className="mt-2 max-w-3xl text-sm text-slate-600">{description}</p>
        </div>
        {!organizationId ? <p className="mt-6 border-l-4 border-amber-500 bg-amber-50 p-4 text-sm text-amber-900">{dictionary.catalog.noOrganization}</p> : null}
        <div className="mt-6"><CatalogReferenceManager kind={kind} items={items} dictionary={dictionary} /></div>
      </main>
    </div>
  );
}
