import Link from "next/link";

type PlaceholderPageProps = {
  eyebrow: string;
  title: string;
  description: string;
  status: string;
};

export function PlaceholderPage({ eyebrow, title, description, status }: PlaceholderPageProps) {
  return (
    <main className="mx-auto flex w-full max-w-6xl flex-1 items-center px-4 py-12 sm:px-6 sm:py-16 lg:px-8">
      <section className="w-full border-y border-slate-200 py-10 sm:py-14">
        <div className="max-w-3xl">
          <p className="text-sm font-semibold uppercase text-emerald-700">{eyebrow}</p>
          <h1 className="mt-3 text-3xl font-bold text-slate-950 sm:text-4xl">{title}</h1>
          <p className="mt-4 max-w-2xl text-base leading-7 text-slate-600 sm:text-lg">{description}</p>

          <div className="mt-8 flex flex-col gap-4 border-l-4 border-amber-400 bg-amber-50 p-4 sm:flex-row sm:items-center sm:justify-between">
            <p className="text-sm font-medium text-amber-950">{status}</p>
            <Link href="/" className="text-sm font-semibold text-emerald-700 hover:text-emerald-800">
              Back to overview
            </Link>
          </div>
        </div>
      </section>
    </main>
  );
}

