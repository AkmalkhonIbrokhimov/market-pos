"use server";

import { redirect } from "next/navigation";

import { isRole } from "@/constants/roles";
import { ROUTES } from "@/constants/routes";
import { getHomeRouteForRole } from "@/lib/auth/permissions";
import { createClient } from "@/lib/supabase/server";
import type { LoginActionState } from "@/types/auth";

function getAuthErrorMessage(message: string): string {
  const normalizedMessage = message.toLowerCase();

  if (normalizedMessage.includes("invalid login credentials")) {
    return "Invalid email or password.";
  }

  if (normalizedMessage.includes("email not confirmed")) {
    return "Your email address has not been confirmed.";
  }

  return "Unable to sign in. Please check your credentials and try again.";
}

async function clearLocalSession() {
  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" });
}

export async function login(
  _previousState: LoginActionState,
  formData: FormData,
): Promise<LoginActionState> {
  void _previousState;

  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) {
    return { error: "Enter both your email and password." };
  }

  const supabase = await createClient();
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (authError || !authData.user) {
    return { error: getAuthErrorMessage(authError?.message ?? "") };
  }

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role, status")
    .eq("auth_user_id", authData.user.id)
    .maybeSingle();

  if (profileError) {
    await clearLocalSession();
    return { error: "Unable to load your user profile. Please try again." };
  }

  if (!profile) {
    await clearLocalSession();
    return { error: "No Market POS profile is linked to this account." };
  }

  if (profile.status === "blocked") {
    await clearLocalSession();
    return { error: "This account is blocked. Contact your store owner." };
  }

  if (profile.status !== "active") {
    await clearLocalSession();
    return { error: "This account is inactive. Contact your store owner." };
  }

  if (!isRole(profile.role)) {
    await clearLocalSession();
    return { error: "This account has an unsupported role." };
  }

  redirect(getHomeRouteForRole(profile.role));
}

export async function logout(): Promise<void> {
  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" });
  redirect(ROUTES.LOGIN);
}
