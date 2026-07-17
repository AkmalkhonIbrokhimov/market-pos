import { createClient } from "@/lib/supabase/server";
import type { CatalogReference } from "@/types/catalog";

export async function listBrands(
  organizationId: string,
  includeArchived = true,
): Promise<CatalogReference[]> {
  const supabase = await createClient();
  let query = supabase
    .from("brands")
    .select("id, name, description, status, archived_at")
    .eq("organization_id", organizationId)
    .order("name");

  if (!includeArchived) {
    query = query.eq("status", "active").is("archived_at", null);
  }

  const { data, error } = await query;
  if (error) throw new Error("Unable to load brands.");

  return (data ?? []).map((item) => ({
    id: item.id,
    name: item.name,
    description: item.description,
    status: item.status,
    archivedAt: item.archived_at,
  }));
}
