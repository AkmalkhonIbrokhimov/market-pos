import { createClient } from "@/lib/supabase/server";
import type { Supplier } from "@/types/stock";

export async function listSuppliers(organizationId: string): Promise<Supplier[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("suppliers")
    .select("id, name")
    .eq("organization_id", organizationId)
    .eq("status", "active")
    .order("name");

  if (error) {
    throw new Error("Unable to load suppliers.");
  }

  return data ?? [];
}
