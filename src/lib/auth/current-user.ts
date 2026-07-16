import type { User } from "@supabase/supabase-js";

import { isRole, type Role } from "@/constants/roles";
import { createClient } from "@/lib/supabase/server";

export type CurrentUser = {
  authUser: User;
  profile: {
    id: string;
    fullName: string;
    email: string | null;
    organizationId: string | null;
    role: Role;
  };
};

export async function getCurrentUser(): Promise<CurrentUser | null> {
  const supabase = await createClient();
  const {
    data: { user: authUser },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !authUser) {
    return null;
  }

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("id, full_name, email, organization_id, role, status")
    .eq("auth_user_id", authUser.id)
    .maybeSingle();

  if (profileError || !profile || profile.status !== "active" || !isRole(profile.role)) {
    return null;
  }

  return {
    authUser,
    profile: {
      id: profile.id,
      fullName: profile.full_name,
      email: profile.email,
      organizationId: profile.organization_id,
      role: profile.role,
    },
  };
}
