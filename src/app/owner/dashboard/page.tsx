import type { Metadata } from "next";
import Link from "next/link";

import { OwnerHeader } from "@/components/owner-header";
import { ROUTES } from "@/constants/routes";
import { getDictionary } from "@/i18n/server";
import { requireOwnerManager } from "@/lib/auth/guards";

export const metadata: Metadata = { title: "Owner dashboard" };
export const dynamic = "force-dynamic";

export default async function OwnerDashboardPage() {
  const [, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const cards = [
    { href: ROUTES.OWNER_PRODUCTS, ...dictionary.roadmap.cards.catalog },
    { href: ROUTES.OWNER_STOCK_INCOME, ...dictionary.roadmap.cards.stock },
    { href: ROUTES.OWNER_PRICING_CALCULATOR, ...dictionary.roadmap.cards.pricing },
    { href: ROUTES.OWNER_STOCK_SUPPLIERS, ...dictionary.roadmap.cards.suppliers },
    { href: "#reports-later", ...dictionary.roadmap.cards.reports },
  ];

  return (
    <div className="min-h-screen bg-slate-50">
      <OwnerHeader dictionary={dictionary} />
      <main className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="border-b border-slate-200 pb-6">
          <p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.owner.eyebrow}</p>
          <h1 className="mt-2 text-3xl font-bold text-slate-950">{dictionary.owner.dashboard}</h1>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">{dictionary.owner.description}</p>
        </div>

        <section className="py-8" aria-labelledby="roadmap-overview-title">
          <h2 id="roadmap-overview-title" className="text-xl font-bold text-slate-950">
            {dictionary.roadmap.overviewTitle}
          </h2>
          <p className="mt-2 text-sm text-slate-600">{dictionary.roadmap.overviewDescription}</p>
          <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {cards.map((card) => (
              <Link
                id={card.href === "#reports-later" ? "reports-later" : undefined}
                key={card.href}
                href={card.href}
                className="border border-slate-200 bg-white p-5 hover:border-emerald-300 hover:bg-emerald-50/40"
              >
                <h3 className="text-lg font-bold text-slate-950">{card.title}</h3>
                <p className="mt-2 text-sm leading-6 text-slate-600">{card.description}</p>
                <p className="mt-5 text-sm font-semibold text-emerald-700">
                  {dictionary.roadmap.openModule}
                </p>
              </Link>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}
