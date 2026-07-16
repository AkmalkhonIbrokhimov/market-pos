"use client";

import { useRouter } from "next/navigation";
import type { ChangeEvent } from "react";

import { LANGUAGE_OPTIONS, LOCALE_COOKIE_NAME } from "@/i18n/config";
import type { Locale } from "@/i18n/types";

type LanguageSwitcherProps = {
  currentLocale: Locale;
  label: string;
};

export function LanguageSwitcher({ currentLocale, label }: LanguageSwitcherProps) {
  const router = useRouter();

  function changeLocale(event: ChangeEvent<HTMLSelectElement>) {
    const locale = event.target.value as Locale;
    document.cookie = `${LOCALE_COOKIE_NAME}=${encodeURIComponent(locale)}; path=/; max-age=31536000; samesite=lax`;
    router.refresh();
  }

  return (
    <label className="flex items-center gap-2 text-sm font-medium text-slate-600">
      <span className="sr-only">{label}</span>
      <select
        aria-label={label}
        value={currentLocale}
        onChange={changeLocale}
        className="h-9 border border-slate-300 bg-white px-2 text-sm text-slate-800 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
      >
        {LANGUAGE_OPTIONS.map((option) => (
          <option key={option.locale} value={option.locale}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}
