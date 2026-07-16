import type { Metadata } from "next";

import { SiteHeader } from "@/components/site-header";
import { getDictionary, getLocale } from "@/i18n/server";

import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Market POS",
    template: "%s | Market POS",
  },
  description: "Offline-first retail management for small shops.",
};

export default async function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const [locale, dictionary] = await Promise.all([getLocale(), getDictionary()]);

  return (
    <html lang={locale}>
      <body className="flex min-h-screen flex-col">
        <SiteHeader dictionary={dictionary} locale={locale} />
        {children}
      </body>
    </html>
  );
}

