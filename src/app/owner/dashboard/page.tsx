import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { LogoutButton } from "@/components/logout-button";
import { PlaceholderPage } from "@/components/placeholder-page";
import { ROUTES } from "@/constants/routes";
import { getCurrentUser } from "@/lib/auth/current-user";

export const metadata: Metadata = { title: "Owner dashboard" };
export const dynamic = "force-dynamic";

export default async function OwnerDashboardPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect(ROUTES.LOGIN);
  }

  return (
    <PlaceholderPage
      eyebrow="Owner workspace"
      title="Dashboard"
      description="This area will give shop owners a clear view of inventory, sales, debts, shifts, and business performance."
      status="Sprint 1 route placeholder — dashboard data is not connected yet."
      action={<LogoutButton />}
    />
  );
}
