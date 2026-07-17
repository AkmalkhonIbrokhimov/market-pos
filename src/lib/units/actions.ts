"use server";

import { createCatalogReference, setCatalogReferenceArchiveState } from "@/lib/catalog-reference/helpers";
import type { CatalogActionState } from "@/types/catalog";

export async function createUnit(_: CatalogActionState, data: FormData) {
  return createCatalogReference("unit", data);
}
export async function archiveUnit(_: CatalogActionState, data: FormData) {
  return setCatalogReferenceArchiveState("unit", data, true);
}
export async function restoreUnit(_: CatalogActionState, data: FormData) {
  return setCatalogReferenceArchiveState("unit", data, false);
}
