import Link from "next/link";

const workspaces = [
  {
    href: "/owner/dashboard",
    label: "Owner dashboard",
    description: "A control center for stock, sellers, debts, shifts, and reports.",
  },
  {
    href: "/seller/pos",
    label: "Seller POS",
    description: "A fast selling workspace designed for reliable offline operation.",
  },
];

export default function Home() {
  return (
    <main className="flex-1">
      <section className="border-b border-slate-200 bg-white">
        <div className="mx-auto grid max-w-6xl gap-10 px-4 py-14 sm:px-6 sm:py-20 lg:grid-cols-[1.3fr_0.7fr] lg:items-end lg:px-8">
          <div>
            <p className="text-sm font-semibold uppercase text-emerald-700">Offline-first retail</p>
            <h1 className="mt-3 text-4xl font-bold text-slate-950 sm:text-5xl">Market POS</h1>
            <p className="mt-5 max-w-2xl text-lg leading-8 text-slate-600">
              A practical retail management system that gives sellers a fast point of sale and owners clear control of their shop.
            </p>
          </div>

          <div className="border-l-4 border-amber-400 bg-amber-50 p-5">
            <p className="text-sm font-semibold text-amber-950">MVP foundation</p>
            <p className="mt-2 text-sm leading-6 text-amber-900">
              Products, stock, sales, debts, shifts, reports, reorder planning, and offline synchronization.
            </p>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold text-emerald-700">Two focused modes</p>
            <h2 className="mt-2 text-2xl font-bold text-slate-950">Seller speed. Owner control.</h2>
          </div>
          <Link href="/login" className="text-sm font-semibold text-emerald-700 hover:text-emerald-800">
            Open login placeholder
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
              <p className="mt-5 text-sm font-semibold text-emerald-700">View workspace</p>
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}

