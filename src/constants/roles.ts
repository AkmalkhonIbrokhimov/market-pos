export const ROLES = {
  OWNER: "owner",
  SELLER: "seller",
  SERVICE_ADMIN: "service_admin",
} as const;

export type Role = (typeof ROLES)[keyof typeof ROLES];
