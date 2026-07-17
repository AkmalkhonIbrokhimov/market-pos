import { createClient } from "@/lib/supabase/server";
import type { ProductTypeReference } from "@/types/catalog";

export async function listProductTypes(
  organizationId: string,
  includeArchived = true,
): Promise<ProductTypeReference[]> {
  const supabase = await createClient();
  let query = supabase
    .from("product_types")
    .select("id, name, code, description, status, archived_at")
    .eq("organization_id", organizationId)
    .order("name");

  if (!includeArchived) {
    query = query.eq("status", "active").is("archived_at", null);
  }

  const { data, error } = await query;
  if (error) throw new Error("Unable to load product types.");

  return (data ?? []).map((item) => ({
    id: item.id,
    name: item.name,
    code: item.code,
    description: item.description,
    status: item.status,
    archivedAt: item.archived_at,
  }));
}
