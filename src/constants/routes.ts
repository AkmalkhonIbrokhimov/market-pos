export const ROUTES = {
  HOME: "/",
  LOGIN: "/login",
  OWNER_DASHBOARD: "/owner/dashboard",
  OWNER_PRODUCTS: "/owner/products",
  OWNER_NEW_PRODUCT: "/owner/products/new",
  OWNER_CATEGORIES: "/owner/categories",
  OWNER_STOCK_INCOME: "/owner/stock/income",
  OWNER_STOCK_INCOME_HISTORY: "/owner/stock/income/history",
  SELLER_POS: "/seller/pos",
} as const;

export type AppRoute = (typeof ROUTES)[keyof typeof ROUTES];

export function getOwnerProductEditRoute(id: string): string {
  return `/owner/products/${id}/edit`;
}
