export const ROUTES = {
  HOME: "/",
  LOGIN: "/login",
  OWNER_DASHBOARD: "/owner/dashboard",
  OWNER_PRODUCTS: "/owner/products",
  OWNER_NEW_PRODUCT: "/owner/products/new",
  OWNER_CATEGORIES: "/owner/categories",
  OWNER_CATALOG_BRANDS: "/owner/catalog/brands",
  OWNER_CATALOG_UNITS: "/owner/catalog/units",
  OWNER_CATALOG_PRODUCT_TYPES: "/owner/catalog/product-types",
  OWNER_CATALOG_ARCHIVE: "/owner/catalog/archive",
  OWNER_CATALOG_IMPORT: "/owner/catalog/import",
  OWNER_CATALOG_EXPORT: "/owner/catalog/export",
  OWNER_CATALOG_PRINT_PRICE_TAGS: "/owner/catalog/print-price-tags",
  OWNER_CATALOG_PRINT_BARCODES: "/owner/catalog/print-barcodes",
  OWNER_STOCK_INCOME: "/owner/stock/income",
  OWNER_STOCK_INCOME_HISTORY: "/owner/stock/income/history",
  OWNER_STOCK_INVOICES: "/owner/stock/invoices",
  OWNER_STOCK_SUPPLIERS: "/owner/stock/suppliers",
  OWNER_STOCK_RECOMMENDED_ORDER: "/owner/stock/recommended-order",
  OWNER_STOCK_EXPIRATION: "/owner/stock/expiration",
  OWNER_STOCK_MOVEMENTS: "/owner/stock/movements",
  OWNER_PRICING_CALCULATOR: "/owner/pricing/calculator",
  OWNER_PRICING_HISTORY: "/owner/pricing/history",
  SELLER_POS: "/seller/pos",
} as const;

export type AppRoute = (typeof ROUTES)[keyof typeof ROUTES];

export function getOwnerProductEditRoute(id: string): string {
  return `/owner/products/${id}/edit`;
}
