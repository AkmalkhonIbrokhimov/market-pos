import type { Metadata } from "next";

import { PlaceholderPage } from "@/components/placeholder-page";

export const metadata: Metadata = { title: "Owner dashboard" };

export default function OwnerDashboardPage() {
  return (
    <PlaceholderPage
      eyebrow="Owner workspace"
      title="Dashboard"
      description="This area will give shop owners a clear view of inventory, sales, debts, shifts, and business performance."
      status="Sprint 1 route placeholder — dashboard data is not connected yet."
    />
  );
}

