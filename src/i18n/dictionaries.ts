import { ROLES, type Role } from "@/constants/roles";
import { en } from "@/i18n/locales/en";
import { ru } from "@/i18n/locales/ru";
import { uzCyrl } from "@/i18n/locales/uz-Cyrl";
import { uzLatn } from "@/i18n/locales/uz-Latn";
import type { Dictionary, Locale } from "@/i18n/types";
import type { CatalogStatus } from "@/types/catalog";

const DICTIONARIES: Record<Locale, Dictionary> = {
  ru,
  en,
  "uz-Latn": uzLatn,
  "uz-Cyrl": uzCyrl,
};

export function getDictionaryForLocale(locale: Locale): Dictionary {
  return DICTIONARIES[locale];
}

export function getStatusLabel(status: CatalogStatus, dictionary: Dictionary): string {
  return status === "active" ? dictionary.common.active : dictionary.common.inactive;
}

export function getRoleLabel(role: Role, dictionary: Dictionary): string {
  if (role === ROLES.OWNER) {
    return dictionary.roles.owner;
  }

  if (role === ROLES.SELLER) {
    return dictionary.roles.seller;
  }

  return dictionary.roles.serviceAdmin;
}
