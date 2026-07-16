"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { ROUTES } from "@/constants/routes";
import { requireOwnerManager } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";
import { getDictionary } from "@/i18n/server";
import type { CatalogActionState, CatalogStatus } from "@/types/catalog";

const VALID_STATUSES: CatalogStatus[] = ["active", "inactive"];

export async function createCategory(
  _previousState: CatalogActionState,
  formData: FormData,
): Promise<CatalogActionState> {
  const currentUser = await requireOwnerManager();
  const dictionary = await getDictionary();
  const organizationId = currentUser.profile.organizationId;
  const name = String(formData.get("name") ?? "").trim();
  const status = String(formData.get("status") ?? "active") as CatalogStatus;

  if (!organizationId) {
    return { error: dictionary.catalog.noOrganization };
  }

  if (!name) {
    return { error: dictionary.catalog.errors.categoryNameRequired };
  }

  if (!VALID_STATUSES.includes(status)) {
    return { error: dictionary.catalog.errors.invalidCategoryStatus };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("categories").insert({
    organization_id: organizationId,
    name,
    status,
  });

  if (error?.code === "23505") {
    return { error: dictionary.catalog.errors.duplicateCategory };
  }

  if (error) {
    return { error: dictionary.catalog.errors.categorySave };
  }

  revalidatePath(ROUTES.OWNER_CATEGORIES);
  revalidatePath(ROUTES.OWNER_PRODUCTS);
  redirect(ROUTES.OWNER_CATEGORIES);
}
