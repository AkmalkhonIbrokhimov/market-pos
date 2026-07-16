import type { NavigationItem } from "@/types/navigation";

import { ROUTES } from "@/constants/routes";

export const navigationItems: NavigationItem[] = [
  { href: ROUTES.HOME, label: "Home" },
  { href: ROUTES.LOGIN, label: "Login" },
  { href: ROUTES.OWNER_DASHBOARD, label: "Owner" },
  { href: ROUTES.SELLER_POS, label: "Seller POS" },
];
