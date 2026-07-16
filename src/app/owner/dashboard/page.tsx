import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { LogoutButton } from "@/components/logout-button";
import { PlaceholderPage } from "@/components/placeholder-page";
import { ROUTES } from "@/constants/routes";
import { getCurrentUser } from "@/lib/auth/current-user";
import { canAccessOwnerDashboard, getHomeRouteForRole } from "@/lib/auth/permissions";

export const metadata: Metadata = { title: "Owner dashboard" };
export const dynamic = "force-dynamic";

export default async function OwnerDashboardPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect(ROUTES.LOGIN);
  }

  if (!canAccessOwnerDashboard(currentUser.profile.role)) {
    redirect(getHomeRouteForRole(currentUser.profile.role));
  }

  return (
    <PlaceholderPage
      eyebrow="Owner workspace"
      title="Dashboard"
      description="This area will give shop owners a clear view of inventory, sales, debts, shifts, and business performance."
      status="Sprint 1 route placeholder — dashboard data is not connected yet."
      action={
        <>
          <Link
            href={ROUTES.OWNER_PRODUCTS}
            className="text-sm font-semibold text-emerald-700 hover:text-emerald-800"
          >
            Manage products
          </Link>
          <LogoutButton />
        </>
      }
    />
  );
}
