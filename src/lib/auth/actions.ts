"use server";

import { redirect } from "next/navigation";

import { isRole } from "@/constants/roles";
import { ROUTES } from "@/constants/routes";
import { getDictionary } from "@/i18n/server";
import type { Dictionary } from "@/i18n/types";
import { getHomeRouteForRole } from "@/lib/auth/permissions";
import { createClient } from "@/lib/supabase/server";
import type { LoginActionState } from "@/types/auth";

function getAuthErrorMessage(message: string, dictionary: Dictionary): string {
  const normalizedMessage = message.toLowerCase();

  if (normalizedMessage.includes("invalid login credentials")) {
    return dictionary.auth.errors.invalidCredentials;
  }

  if (normalizedMessage.includes("email not confirmed")) {
    return dictionary.auth.errors.emailNotConfirmed;
  }

  return dictionary.auth.errors.genericSignIn;
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
  const dictionary = await getDictionary();

  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) {
    return { error: dictionary.auth.errors.requiredCredentials };
  }

  const supabase = await createClient();
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (authError || !authData.user) {
    return { error: getAuthErrorMessage(authError?.message ?? "", dictionary) };
  }

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role, status")
    .eq("auth_user_id", authData.user.id)
    .maybeSingle();

  if (profileError) {
    await clearLocalSession();
    return { error: dictionary.auth.errors.profileLoad };
  }

  if (!profile) {
    await clearLocalSession();
    return { error: dictionary.auth.errors.missingProfile };
  }

  if (profile.status === "blocked") {
    await clearLocalSession();
    return { error: dictionary.auth.errors.blocked };
  }

  if (profile.status !== "active") {
    await clearLocalSession();
    return { error: dictionary.auth.errors.inactive };
  }

  if (!isRole(profile.role)) {
    await clearLocalSession();
    return { error: dictionary.auth.errors.unsupportedRole };
  }

  redirect(getHomeRouteForRole(profile.role));
}

export async function logout(): Promise<void> {
  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" });
  redirect(ROUTES.LOGIN);
}
