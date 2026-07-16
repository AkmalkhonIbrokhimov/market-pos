import Link from "next/link";

import { LanguageSwitcher } from "@/components/language-switcher";
import { navigationItems } from "@/constants/navigation";
import type { Dictionary, Locale } from "@/i18n/types";

type SiteHeaderProps = {
  dictionary: Dictionary;
  locale: Locale;
};

export function SiteHeader({ dictionary, locale }: SiteHeaderProps) {
  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex min-h-16 max-w-6xl flex-col justify-center gap-3 px-4 py-3 sm:flex-row sm:items-center sm:justify-between sm:px-6 lg:px-8">
        <Link href="/" className="flex items-center gap-3 font-semibold text-slate-950">
          <span className="grid size-9 place-items-center rounded-lg bg-emerald-600 text-sm font-bold text-white">
            MP
          </span>
          <span>Market POS</span>
        </Link>

        <div className="flex flex-wrap items-center gap-x-5 gap-y-3">
          <nav
            aria-label={dictionary.navigation.mainAria}
            className="flex flex-wrap gap-x-5 gap-y-2 text-sm font-medium text-slate-600"
          >
            {navigationItems.map((item) => (
              <Link key={item.href} href={item.href} className="transition-colors hover:text-emerald-700">
                {dictionary.navigation[item.labelKey]}
              </Link>
            ))}
          </nav>
          <LanguageSwitcher currentLocale={locale} label={dictionary.common.language} />
        </div>
      </div>
    </header>
  );
}

