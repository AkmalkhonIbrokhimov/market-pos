"use server";

import { createCatalogReference, setCatalogReferenceArchiveState } from "@/lib/catalog-reference/helpers";
import type { CatalogActionState } from "@/types/catalog";

export async function createBrand(_: CatalogActionState, data: FormData) {
  return createCatalogReference("brand", data);
}
export async function archiveBrand(_: CatalogActionState, data: FormData) {
  return setCatalogReferenceArchiveState("brand", data, true);
}
export async function restoreBrand(_: CatalogActionState, data: FormData) {
  return setCatalogReferenceArchiveState("brand", data, false);
}
