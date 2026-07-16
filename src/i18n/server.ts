import "server-only";

import { cookies } from "next/headers";

import { DEFAULT_LOCALE, LOCALE_COOKIE_NAME, isLocale } from "@/i18n/config";
import { getDictionaryForLocale } from "@/i18n/dictionaries";
import type { Dictionary, Locale } from "@/i18n/types";

export async function getLocale(): Promise<Locale> {
  const cookieStore = await cookies();
  const cookieLocale = cookieStore.get(LOCALE_COOKIE_NAME)?.value;

  return isLocale(cookieLocale) ? cookieLocale : DEFAULT_LOCALE;
}

export async function getDictionary(): Promise<Dictionary> {
  return getDictionaryForLocale(await getLocale());
}
