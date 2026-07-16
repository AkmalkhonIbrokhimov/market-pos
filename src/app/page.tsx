import Link from "next/link";

import { ROUTES } from "@/constants/routes";
import { getDictionary } from "@/i18n/server";

export default async function Home() {
  const dictionary = await getDictionary();
  const workspaces = [
    {
      href: ROUTES.OWNER_DASHBOARD,
      label: dictionary.home.ownerTitle,
      description: dictionary.home.ownerDescription,
    },
    {
      href: ROUTES.SELLER_POS,
      label: dictionary.home.sellerTitle,
      description: dictionary.home.sellerDescription,
    },
  ];

  return (
    <main className="flex-1">
      <section className="border-b border-slate-200 bg-white">
        <div className="mx-auto grid max-w-6xl gap-10 px-4 py-14 sm:px-6 sm:py-20 lg:grid-cols-[1.3fr_0.7fr] lg:items-end lg:px-8">
          <div>
            <p className="text-sm font-semibold uppercase text-emerald-700">{dictionary.home.eyebrow}</p>
            <h1 className="mt-3 text-4xl font-bold text-slate-950 sm:text-5xl">{dictionary.home.title}</h1>
            <p className="mt-5 max-w-2xl text-lg leading-8 text-slate-600">
              {dictionary.home.description}
            </p>
          </div>

          <div className="border-l-4 border-amber-400 bg-amber-50 p-5">
            <p className="text-sm font-semibold text-amber-950">{dictionary.home.mvpTitle}</p>
            <p className="mt-2 text-sm leading-6 text-amber-900">
              {dictionary.home.mvpDescription}
            </p>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold text-emerald-700">{dictionary.home.modesEyebrow}</p>
            <h2 className="mt-2 text-2xl font-bold text-slate-950">{dictionary.home.modesTitle}</h2>
          </div>
          <Link href={ROUTES.LOGIN} className="text-sm font-semibold text-emerald-700 hover:text-emerald-800">
            {dictionary.home.openLogin}
          </Link>
        </div>

        <div className="mt-8 grid gap-5 md:grid-cols-2">
          {workspaces.map((workspace) => (
            <Link
              key={workspace.href}
              href={workspace.href}
              className="rounded-lg border border-slate-200 bg-white p-6 transition-colors hover:border-emerald-300 hover:bg-emerald-50/40"
            >
              <h3 className="text-lg font-semibold text-slate-950">{workspace.label}</h3>
              <p className="mt-2 text-sm leading-6 text-slate-600">{workspace.description}</p>
              <p className="mt-5 text-sm font-semibold text-emerald-700">{dictionary.home.viewWorkspace}</p>
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}

