import { createClient } from "@/lib/supabase/server";
import type { UnitReference } from "@/types/catalog";

export async function listUnits(
  organizationId: string,
  includeArchived = true,
): Promise<UnitReference[]> {
  const supabase = await createClient();
  let query = supabase
    .from("units")
    .select("id, name, short_name, status, archived_at")
    .eq("organization_id", organizationId)
    .order("name");

  if (!includeArchived) {
    query = query.eq("status", "active").is("archived_at", null);
  }

  const { data, error } = await query;
  if (error) throw new Error("Unable to load units.");

  return (data ?? []).map((item) => ({
    id: item.id,
    name: item.name,
    shortName: item.short_name,
    status: item.status,
    archivedAt: item.archived_at,
  }));
}
