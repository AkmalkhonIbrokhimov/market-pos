import { redirect } from "next/navigation";

import { ROUTES } from "@/constants/routes";
import { getCurrentUser } from "@/lib/auth/current-user";
import { canAccessOwnerDashboard, getHomeRouteForRole } from "@/lib/auth/permissions";

export async function requireOwnerManager() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect(ROUTES.LOGIN);
  }

  if (!canAccessOwnerDashboard(currentUser.profile.role)) {
    redirect(getHomeRouteForRole(currentUser.profile.role));
  }

  return currentUser;
}
