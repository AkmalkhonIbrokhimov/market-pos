"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import { login } from "@/lib/auth/actions";
import type { LoginActionState } from "@/types/auth";

const initialState: LoginActionState = { error: null };

function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className="h-11 w-full rounded-lg bg-emerald-700 px-4 text-sm font-semibold text-white transition-colors hover:bg-emerald-800 disabled:cursor-not-allowed disabled:bg-slate-400"
    >
      {pending ? "Signing in..." : "Sign in"}
    </button>
  );
}

export function LoginForm() {
  const [state, formAction] = useActionState(login, initialState);

  return (
    <form action={formAction} className="mt-8 space-y-5">
      <div>
        <label htmlFor="email" className="block text-sm font-semibold text-slate-800">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          required
          className="mt-2 h-11 w-full rounded-lg border border-slate-300 bg-white px-3 text-base text-slate-950 outline-none transition-colors placeholder:text-slate-400 focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
          placeholder="you@example.com"
        />
      </div>

      <div>
        <label htmlFor="password" className="block text-sm font-semibold text-slate-800">
          Password
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          className="mt-2 h-11 w-full rounded-lg border border-slate-300 bg-white px-3 text-base text-slate-950 outline-none transition-colors focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
        />
      </div>

      {state.error ? (
        <p role="alert" className="border-l-4 border-red-500 bg-red-50 p-3 text-sm font-medium text-red-800">
          {state.error}
        </p>
      ) : null}

      <SubmitButton />
    </form>
  );
}
