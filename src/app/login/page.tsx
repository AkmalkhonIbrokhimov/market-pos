import type { Metadata } from "next";

import { PlaceholderPage } from "@/components/placeholder-page";

export const metadata: Metadata = { title: "Login" };

export default function LoginPage() {
  return (
    <PlaceholderPage
      eyebrow="Account access"
      title="Login"
      description="The entry point for owners and sellers will live here. Authentication is intentionally deferred until the next sprint."
      status="Placeholder only — no credentials are collected or submitted."
    />
  );
}

