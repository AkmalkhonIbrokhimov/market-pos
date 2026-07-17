import Link from "next/link";

import { OwnerHeader } from "@/components/owner-header";
import { ROUTES, type AppRoute } from "@/constants/routes";
import { getDictionary } from "@/i18n/server";
import type { Dictionary } from "@/i18n/types";
import { requireOwnerManager } from "@/lib/auth/guards";

export type RoadmapModuleKey = keyof Dictionary["roadmap"]["modules"];
type RoadmapArea = "catalog" | "stock" | "pricing";

type OwnerRoadmapPageProps = {
  area: RoadmapArea;
  moduleKey: RoadmapModuleKey;
};

const BACK_ROUTES: Record<RoadmapArea, AppRoute> = {
  catalog: ROUTES.OWNER_PRODUCTS,
  stock: ROUTES.OWNER_STOCK_INCOME,
  pricing: ROUTES.OWNER_DASHBOARD,
};

export async function OwnerRoadmapPage({ area, moduleKey }: OwnerRoadmapPageProps) {
  const [, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const moduleCopy = dictionary.roadmap.modules[moduleKey];
  const backLabels = {
    catalog: dictionary.roadmap.backToCatalog,
    stock: dictionary.roadmap.backToStock,
    pricing: dictionary.roadmap.backToPricing,
  };

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-6xl px-4 py-10 sm:px-6 lg:px-8">
        <section className="border-y border-slate-200 py-10 sm:py-14">
          <div className="max-w-3xl">
            <p className="text-sm font-semibold uppercase text-emerald-700">
              {dictionary.roadmap[area]}
            </p>
            <h1 className="mt-3 text-3xl font-bold text-slate-950 sm:text-4xl">{moduleCopy.title}</h1>
            <p className="mt-4 text-base leading-7 text-slate-600 sm:text-lg">
              {moduleCopy.description}
            </p>
            <div className="mt-8 flex flex-col gap-4 border-l-4 border-amber-400 bg-amber-50 p-4 sm:flex-row sm:items-center sm:justify-between">
              <span className="w-fit border border-amber-300 bg-white px-2.5 py-1 text-xs font-bold uppercase text-amber-900">
                {dictionary.roadmap.plannedModule}
              </span>
              <Link
                href={BACK_ROUTES[area]}
                className="text-sm font-semibold text-emerald-700 hover:text-emerald-800"
              >
                {backLabels[area]}
              </Link>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
