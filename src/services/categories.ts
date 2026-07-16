import { createClient } from "@/lib/supabase/server";
import type { Category } from "@/types/catalog";

export async function listCategories(organizationId: string): Promise<Category[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("categories")
    .select("id, name, status")
    .eq("organization_id", organizationId)
    .order("name");

  if (error) {
    throw new Error("Unable to load categories.");
  }

  return (data ?? []).map((category) => ({
    id: category.id,
    name: category.name,
    status: category.status,
  }));
}
