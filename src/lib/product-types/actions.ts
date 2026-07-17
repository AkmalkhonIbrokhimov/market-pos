"use server";

import { createCatalogReference, setCatalogReferenceArchiveState } from "@/lib/catalog-reference/helpers";
import type { CatalogActionState } from "@/types/catalog";

export async function createProductType(_: CatalogActionState, data: FormData) {
  return createCatalogReference("productType", data);
}
export async function archiveProductType(_: CatalogActionState, data: FormData) {
  return setCatalogReferenceArchiveState("productType", data, true);
}
export async function restoreProductType(_: CatalogActionState, data: FormData) {
  return setCatalogReferenceArchiveState("productType", data, false);
}
