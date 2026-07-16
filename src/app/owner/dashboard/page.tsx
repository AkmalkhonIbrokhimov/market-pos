import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { LogoutButton } from "@/components/logout-button";
import { PlaceholderPage } from "@/components/placeholder-page";
import { ROUTES } from "@/constants/routes";
import { getDictionary } from "@/i18n/server";
import { getCurrentUser } from "@/lib/auth/current-user";
import { canAccessOwnerDashboard, getHomeRouteForRole } from "@/lib/auth/permissions";

export const metadata: Metadata = { title: "Owner dashboard" };
export const dynamic = "force-dynamic";

export default async function OwnerDashboardPage() {
  const [currentUser, dictionary] = await Promise.all([getCurrentUser(), getDictionary()]);

  if (!currentUser) {
    redirect(ROUTES.LOGIN);
  }

  if (!canAccessOwnerDashboard(currentUser.profile.role)) {
    redirect(getHomeRouteForRole(currentUser.profile.role));
  }

  return (
    <PlaceholderPage
      eyebrow={dictionary.owner.eyebrow}
      title={dictionary.owner.dashboard}
      description={dictionary.owner.description}
      status={dictionary.owner.placeholderStatus}
      backLabel={dictionary.common.backToOverview}
      action={
        <>
          <Link
            href={ROUTES.OWNER_PRODUCTS}
            className="text-sm font-semibold text-emerald-700 hover:text-emerald-800"
          >
            {dictionary.owner.manageProducts}
          </Link>
          <LogoutButton label={dictionary.navigation.logout} />
        </>
      }
    />
  );
}
