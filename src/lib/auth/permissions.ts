import type { Role } from "@/constants/roles";

export function hasRole(currentRole: Role | null, requiredRole: Role): boolean {
  return currentRole === requiredRole;
}
