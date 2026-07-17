import { revalidatePath } from "next/cache";

import { ROUTES } from "@/constants/routes";
import { getDictionary } from "@/i18n/server";
import { requireOwnerManager } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";
import type { CatalogActionState, CatalogStatus } from "@/types/catalog";

export type ReferenceKind = "brand" | "unit" | "productType";

const CONFIG = {
  brand: { table: "brands", route: ROUTES.OWNER_CATALOG_BRANDS },
  unit: { table: "units", route: ROUTES.OWNER_CATALOG_UNITS },
  productType: { table: "product_types", route: ROUTES.OWNER_CATALOG_PRODUCT_TYPES },
} as const;

export async function createCatalogReference(
  kind: ReferenceKind,
  formData: FormData,
): Promise<CatalogActionState> {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const name = String(formData.get("name") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim() || null;
  const shortName = String(formData.get("short_name") ?? "").trim();
  const code = String(formData.get("code") ?? "").trim() || null;
  const status = String(formData.get("status") ?? "active") as CatalogStatus;

  if (!organizationId) return { error: dictionary.catalog.noOrganization };
  if (!name) return { error: dictionary.catalog.errors.referenceNameRequired };
  if (kind === "unit" && !shortName) return { error: dictionary.catalog.errors.unitShortNameRequired };
  if (status !== "active" && status !== "inactive") {
    return { error: dictionary.catalog.errors.invalidReferenceStatus };
  }

  const supabase = await createClient();
  const { error } =
    kind === "unit"
      ? await supabase.from("units").insert({ organization_id: organizationId, name, short_name: shortName, status })
      : kind === "productType"
        ? await supabase.from("product_types").insert({ organization_id: organizationId, name, code, description, status })
        : await supabase.from("brands").insert({ organization_id: organizationId, name, description, status });

  if (error?.code === "23505") return { error: dictionary.catalog.errors.duplicateReference };
  if (error) return { error: dictionary.catalog.errors.referenceSave };

  revalidatePath(CONFIG[kind].route);
  revalidatePath(ROUTES.OWNER_PRODUCTS);
  return { error: null, message: dictionary.catalog.referenceCreated };
}

export async function setCatalogReferenceArchiveState(
  kind: ReferenceKind,
  formData: FormData,
  archived: boolean,
): Promise<CatalogActionState> {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const id = String(formData.get("reference_id") ?? "").trim();

  if (!organizationId) return { error: dictionary.catalog.noOrganization };
  if (!id) return { error: dictionary.catalog.errors.missingReference };

  const supabase = await createClient();
  const payload = {
    archived_at: archived ? new Date().toISOString() : null,
    status: archived ? "inactive" : "active",
  };
  const result =
    kind === "unit"
      ? await supabase.from("units").update(payload).eq("organization_id", organizationId).eq("id", id).select("id").maybeSingle()
      : kind === "productType"
        ? await supabase.from("product_types").update(payload).eq("organization_id", organizationId).eq("id", id).select("id").maybeSingle()
        : await supabase.from("brands").update(payload).eq("organization_id", organizationId).eq("id", id).select("id").maybeSingle();
  const { data, error } = result;

  if (error?.code === "23505") return { error: dictionary.catalog.errors.duplicateReference };
  if (error || !data) return { error: dictionary.catalog.errors.referenceUpdate };

  revalidatePath(CONFIG[kind].route);
  revalidatePath(ROUTES.OWNER_PRODUCTS);
  return {
    error: null,
    message: archived ? dictionary.catalog.referenceArchived : dictionary.catalog.referenceRestored,
  };
}
