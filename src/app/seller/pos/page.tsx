import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { LogoutButton } from "@/components/logout-button";
import { PlaceholderPage } from "@/components/placeholder-page";
import { ROUTES } from "@/constants/routes";
import { getCurrentUser } from "@/lib/auth/current-user";
import { canAccessSellerPos, getHomeRouteForRole } from "@/lib/auth/permissions";

export const metadata: Metadata = { title: "Seller POS" };
export const dynamic = "force-dynamic";

export default async function SellerPosPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect(ROUTES.LOGIN);
  }

  if (!canAccessSellerPos(currentUser.profile.role)) {
    redirect(getHomeRouteForRole(currentUser.profile.role));
  }

  return (
    <PlaceholderPage
      eyebrow="Seller workspace"
      title="Point of sale"
      description="The fast selling interface will live here, with an offline-first workflow for products, payments, debts, and shifts."
      status="Sprint 1 route placeholder — no sales operations are implemented."
      action={<LogoutButton />}
    />
  );
}
