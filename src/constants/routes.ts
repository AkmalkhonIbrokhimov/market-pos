export const ROUTES = {
  HOME: "/",
  LOGIN: "/login",
  OWNER_DASHBOARD: "/owner/dashboard",
  SELLER_POS: "/seller/pos",
} as const;

export type AppRoute = (typeof ROUTES)[keyof typeof ROUTES];
