import type { Metadata } from "next";

import { PlaceholderPage } from "@/components/placeholder-page";

export const metadata: Metadata = { title: "Seller POS" };

export default function SellerPosPage() {
  return (
    <PlaceholderPage
      eyebrow="Seller workspace"
      title="Point of sale"
      description="The fast selling interface will live here, with an offline-first workflow for products, payments, debts, and shifts."
      status="Sprint 1 route placeholder — no sales operations are implemented."
    />
  );
}

