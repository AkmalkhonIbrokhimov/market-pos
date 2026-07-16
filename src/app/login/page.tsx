import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { LoginForm } from "@/components/login-form";
import { getCurrentUser } from "@/lib/auth/current-user";
import { getHomeRouteForRole } from "@/lib/auth/permissions";

export const metadata: Metadata = { title: "Login" };
export const dynamic = "force-dynamic";

export default async function LoginPage() {
  const currentUser = await getCurrentUser();

  if (currentUser) {
    redirect(getHomeRouteForRole(currentUser.profile.role));
  }

  return (
    <main className="mx-auto flex w-full max-w-6xl flex-1 items-center px-4 py-12 sm:px-6 lg:px-8">
      <section className="grid w-full gap-10 border-y border-slate-200 py-10 lg:grid-cols-[1fr_420px] lg:items-center lg:py-14">
        <div className="max-w-xl">
          <p className="text-sm font-semibold uppercase text-emerald-700">Account access</p>
          <h1 className="mt-3 text-3xl font-bold text-slate-950 sm:text-4xl">Welcome back</h1>
          <p className="mt-4 text-base leading-7 text-slate-600 sm:text-lg">
            Sign in with your Market POS account to continue to your assigned workspace.
          </p>
        </div>

        <div className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <h2 className="text-xl font-semibold text-slate-950">Sign in</h2>
          <LoginForm />
        </div>
      </section>
    </main>
  );
}
