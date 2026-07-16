import { ROLES, type Role } from "@/constants/roles";
import { ROUTES, type AppRoute } from "@/constants/routes";

export function hasRole(currentRole: Role | null, requiredRole: Role): boolean {
  return currentRole === requiredRole;
}

export function getHomeRouteForRole(role: Role): AppRoute {
  return role === ROLES.SELLER ? ROUTES.SELLER_POS : ROUTES.OWNER_DASHBOARD;
}
