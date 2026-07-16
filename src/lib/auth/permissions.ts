import { ROLES, type Role } from "@/constants/roles";
import { ROUTES, type AppRoute } from "@/constants/routes";

export function hasRole(currentRole: Role | null, requiredRole: Role): boolean {
  return currentRole === requiredRole;
}

export function canAccessOwnerDashboard(role: Role): boolean {
  return role === ROLES.OWNER || role === ROLES.SERVICE_ADMIN;
}

export function canAccessSellerPos(role: Role): boolean {
  return role === ROLES.SELLER || role === ROLES.OWNER;
}

export function getHomeRouteForRole(role: Role): AppRoute {
  return role === ROLES.SELLER ? ROUTES.SELLER_POS : ROUTES.OWNER_DASHBOARD;
}
