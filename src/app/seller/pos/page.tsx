import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { LogoutButton } from "@/components/logout-button";
import { PlaceholderPage } from "@/components/placeholder-page";
import { ROUTES } from "@/constants/routes";
import { getDictionary } from "@/i18n/server";
import { getCurrentUser } from "@/lib/auth/current-user";
import { canAccessSellerPos, getHomeRouteForRole } from "@/lib/auth/permissions";

export const metadata: Metadata = { title: "Seller POS" };
export const dynamic = "force-dynamic";

export default async function SellerPosPage() {
  const [currentUser, dictionary] = await Promise.all([getCurrentUser(), getDictionary()]);

  if (!currentUser) {
    redirect(ROUTES.LOGIN);
  }

  if (!canAccessSellerPos(currentUser.profile.role)) {
    redirect(getHomeRouteForRole(currentUser.profile.role));
  }

  return (
    <PlaceholderPage
      eyebrow={dictionary.seller.eyebrow}
      title={dictionary.seller.title}
      description={dictionary.seller.description}
      status={dictionary.seller.placeholderStatus}
      backLabel={dictionary.common.backToOverview}
      action={<LogoutButton label={dictionary.navigation.logout} />}
    />
  );
}
