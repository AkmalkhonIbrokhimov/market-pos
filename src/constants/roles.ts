export const ROLES = {
  OWNER: "owner",
  SELLER: "seller",
  SERVICE_ADMIN: "service_admin",
} as const;

export type Role = (typeof ROLES)[keyof typeof ROLES];

export function isRole(value: unknown): value is Role {
  return value === ROLES.OWNER || value === ROLES.SELLER || value === ROLES.SERVICE_ADMIN;
}
