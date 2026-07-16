"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { ROUTES } from "@/constants/routes";
import { requireOwnerManager } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";
import type { CatalogActionState, CatalogStatus } from "@/types/catalog";

const VALID_STATUSES: CatalogStatus[] = ["active", "inactive"];

export async function createCategory(
  _previousState: CatalogActionState,
  formData: FormData,
): Promise<CatalogActionState> {
  const currentUser = await requireOwnerManager();
  const organizationId = currentUser.profile.organizationId;
  const name = String(formData.get("name") ?? "").trim();
  const status = String(formData.get("status") ?? "active") as CatalogStatus;

  if (!organizationId) {
    return { error: "Your user profile is not assigned to an organization." };
  }

  if (!name) {
    return { error: "Category name is required." };
  }

  if (!VALID_STATUSES.includes(status)) {
    return { error: "Choose a valid category status." };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("categories").insert({
    organization_id: organizationId,
    name,
    status,
  });

  if (error?.code === "23505") {
    return { error: "A category with this name already exists." };
  }

  if (error) {
    return { error: "Unable to add the category. Please try again." };
  }

  revalidatePath(ROUTES.OWNER_CATEGORIES);
  revalidatePath(ROUTES.OWNER_PRODUCTS);
  redirect(ROUTES.OWNER_CATEGORIES);
}
