import type { NavigationItem } from "@/types/navigation";

import { ROUTES } from "@/constants/routes";

export const navigationItems: NavigationItem[] = [
  { href: ROUTES.HOME, labelKey: "home" },
  { href: ROUTES.LOGIN, labelKey: "login" },
  { href: ROUTES.OWNER_DASHBOARD, labelKey: "owner" },
  { href: ROUTES.SELLER_POS, labelKey: "sellerPos" },
];
