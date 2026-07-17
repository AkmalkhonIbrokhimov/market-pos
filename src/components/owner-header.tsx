import Link from "next/link";

import { LogoutButton } from "@/components/logout-button";
import { ROUTES } from "@/constants/routes";
import type { Dictionary } from "@/i18n/types";

type OwnerMenuProps = {
  label: string;
  links: Array<{ href: string; label: string }>;
};

function OwnerMenu({ label, links }: OwnerMenuProps) {
  return (
    <details className="group relative">
      <summary className="cursor-pointer text-sm font-semibold text-slate-700 hover:text-emerald-700">
        {label}
      </summary>
      <div className="absolute right-0 z-30 mt-3 grid w-72 gap-1 border border-slate-200 bg-white p-2 shadow-lg">
        {links.map((link) => (
          <Link
            key={link.href}
            href={link.href}
            className="px-3 py-2 text-sm font-medium text-slate-700 hover:bg-emerald-50 hover:text-emerald-800"
          >
            {link.label}
          </Link>
        ))}
      </div>
    </details>
  );
}

export function OwnerHeader({ dictionary }: { dictionary: Dictionary }) {
  const catalogLinks = [
    { href: ROUTES.OWNER_PRODUCTS, label: dictionary.navigation.products },
    { href: ROUTES.OWNER_CATEGORIES, label: dictionary.navigation.categories },
    { href: ROUTES.OWNER_CATALOG_BRANDS, label: dictionary.roadmap.modules.brands.title },
    { href: ROUTES.OWNER_CATALOG_UNITS, label: dictionary.roadmap.modules.units.title },
    { href: ROUTES.OWNER_CATALOG_PRODUCT_TYPES, label: dictionary.roadmap.modules.productTypes.title },
    { href: ROUTES.OWNER_CATALOG_ARCHIVE, label: dictionary.roadmap.modules.productArchive.title },
    { href: ROUTES.OWNER_CATALOG_IMPORT, label: dictionary.roadmap.modules.importExcel.title },
    { href: ROUTES.OWNER_CATALOG_EXPORT, label: dictionary.roadmap.modules.exportExcel.title },
    { href: ROUTES.OWNER_CATALOG_PRINT_PRICE_TAGS, label: dictionary.roadmap.modules.printPriceTags.title },
    { href: ROUTES.OWNER_CATALOG_PRINT_BARCODES, label: dictionary.roadmap.modules.printBarcodes.title },
  ];
  const stockLinks = [
    { href: ROUTES.OWNER_STOCK_INCOME, label: dictionary.stock.income },
    { href: ROUTES.OWNER_STOCK_INCOME_HISTORY, label: dictionary.stock.history },
    { href: ROUTES.OWNER_STOCK_INVOICES, label: dictionary.roadmap.modules.invoices.title },
    { href: ROUTES.OWNER_STOCK_SUPPLIERS, label: dictionary.roadmap.modules.suppliers.title },
    { href: ROUTES.OWNER_STOCK_RECOMMENDED_ORDER, label: dictionary.roadmap.modules.recommendedOrder.title },
    { href: ROUTES.OWNER_STOCK_EXPIRATION, label: dictionary.roadmap.modules.expirationControl.title },
    { href: ROUTES.OWNER_STOCK_MOVEMENTS, label: dictionary.roadmap.modules.stockMovements.title },
  ];
  const pricingLinks = [
    { href: ROUTES.OWNER_PRICING_CALCULATOR, label: dictionary.roadmap.modules.priceCalculator.title },
    { href: ROUTES.OWNER_PRICING_HISTORY, label: dictionary.roadmap.modules.priceHistory.title },
  ];

  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex w-full max-w-7xl flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <Link href={ROUTES.OWNER_DASHBOARD} className="text-lg font-bold text-slate-950">
          Market POS
        </Link>
        <nav aria-label={dictionary.navigation.ownerAria} className="flex flex-wrap items-center gap-5">
          <Link
            href={ROUTES.OWNER_DASHBOARD}
            className="text-sm font-semibold text-slate-700 hover:text-emerald-700"
          >
            {dictionary.owner.dashboard}
          </Link>
          <OwnerMenu label={dictionary.roadmap.catalog} links={catalogLinks} />
          <OwnerMenu label={dictionary.roadmap.stock} links={stockLinks} />
          <OwnerMenu label={dictionary.roadmap.pricing} links={pricingLinks} />
          <LogoutButton label={dictionary.navigation.logout} />
        </nav>
      </div>
    </header>
  );
}
