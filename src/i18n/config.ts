import type { Locale } from "@/i18n/types";

export const DEFAULT_LOCALE: Locale = "ru";
export const LOCALE_COOKIE_NAME = "market-pos-locale";

export const LOCALES: readonly Locale[] = ["ru", "en", "uz-Latn", "uz-Cyrl"];

export const LANGUAGE_OPTIONS: ReadonlyArray<{ locale: Locale; label: string }> = [
  { locale: "ru", label: "Русский" },
  { locale: "en", label: "English" },
  { locale: "uz-Latn", label: "O‘zbek" },
  { locale: "uz-Cyrl", label: "Ўзбек" },
];

export function isLocale(value: string | undefined): value is Locale {
  return LOCALES.some((locale) => locale === value);
}
