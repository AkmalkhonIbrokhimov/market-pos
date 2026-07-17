"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  ROUTES,
  getOwnerProductEditRoute,
  getOwnerProductRoute,
} from "@/constants/routes";
import { getDictionary } from "@/i18n/server";
import type { Dictionary } from "@/i18n/types";
import { requireOwnerManager } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";
import type { CatalogActionState, CatalogStatus } from "@/types/catalog";

type ProductInput = {
  name: string;
  categoryId: string | null;
  sku: string | null;
  barcode: string | null;
  brandId: string | null;
  productTypeId: string | null;
  unitId: string | null;
  unit: string;
  salePrice: number;
  minQuantity: number;
  isExpirable: boolean;
  status: CatalogStatus;
  description: string | null;
  imageUrl: string | null;
  weight: number | null;
  weightUnit: string | null;
  volume: number | null;
  volumeUnit: string | null;
  sizeText: string | null;
  color: string | null;
  packageSize: string | null;
};

function optionalText(formData: FormData, name: string): string | null {
  return String(formData.get(name) ?? "").trim() || null;
}

function parseNumber(value: FormDataEntryValue | null, required: boolean): number | null | undefined {
  const raw = String(value ?? "").trim();
  if (!raw) return required ? undefined : null;
  const number = Number(raw);
  return Number.isFinite(number) && number >= 0 ? number : undefined;
}

function parseProductInput(formData: FormData, dictionary: Dictionary): ProductInput | CatalogActionState {
  const name = String(formData.get("name") ?? "").trim();
  const salePrice = parseNumber(formData.get("sale_price"), true);
  const minQuantity = parseNumber(formData.get("min_quantity"), true);
  const weight = parseNumber(formData.get("weight"), false);
  const volume = parseNumber(formData.get("volume"), false);
  const status = String(formData.get("status") ?? "active") as CatalogStatus;
  const imageUrl = optionalText(formData, "image_url");

  if (!name) return { error: dictionary.catalog.errors.productNameRequired };
  if (typeof salePrice !== "number") return { error: dictionary.catalog.errors.salePriceInvalid };
  if (typeof minQuantity !== "number") return { error: dictionary.catalog.errors.minimumQuantityInvalid };
  if (weight === undefined) return { error: dictionary.catalog.errors.weightInvalid };
  if (volume === undefined) return { error: dictionary.catalog.errors.volumeInvalid };
  if (status !== "active" && status !== "inactive") {
    return { error: dictionary.catalog.errors.invalidProductStatus };
  }
  if (imageUrl) {
    try {
      const url = new URL(imageUrl);
      if (url.protocol !== "http:" && url.protocol !== "https:") throw new Error();
    } catch {
      return { error: dictionary.catalog.errors.imageUrlInvalid };
    }
  }

  return {
    name,
    categoryId: optionalText(formData, "category_id"),
    sku: optionalText(formData, "sku"),
    barcode: optionalText(formData, "barcode"),
    brandId: optionalText(formData, "brand_id"),
    productTypeId: optionalText(formData, "product_type_id"),
    unitId: optionalText(formData, "unit_id"),
    unit: optionalText(formData, "unit") ?? "шт",
    salePrice,
    minQuantity,
    isExpirable: formData.get("is_expirable") === "on",
    status,
    description: optionalText(formData, "description"),
    imageUrl,
    weight,
    weightUnit: optionalText(formData, "weight_unit") ?? "kg",
    volume,
    volumeUnit: optionalText(formData, "volume_unit") ?? "l",
    sizeText: optionalText(formData, "size_text"),
    color: optionalText(formData, "color"),
    packageSize: optionalText(formData, "package_size"),
  };
}

async function validateReference(
  organizationId: string,
  table: "categories" | "brands" | "units" | "product_types",
  id: string | null,
): Promise<boolean> {
  if (!id) return true;
  const supabase = await createClient();
  const { data, error } = await supabase
    .from(table)
    .select("id")
    .eq("organization_id", organizationId)
    .eq("id", id)
    .maybeSingle();
  return !error && Boolean(data);
}

function toPayload(organizationId: string, input: ProductInput) {
  return {
    organization_id: organizationId,
    name: input.name,
    category_id: input.categoryId,
    sku: input.sku,
    barcode: input.barcode,
    brand_id: input.brandId,
    product_type_id: input.productTypeId,
    unit_id: input.unitId,
    unit: input.unit,
    sale_price: input.salePrice,
    min_quantity: input.minQuantity,
    is_expirable: input.isExpirable,
    status: input.status,
    description: input.description,
    image_url: input.imageUrl,
    weight: input.weight,
    weight_unit: input.weightUnit,
    volume: input.volume,
    volume_unit: input.volumeUnit,
    size_text: input.sizeText,
    color: input.color,
    package_size: input.packageSize,
  };
}

async function validateInputReferences(organizationId: string, input: ProductInput): Promise<boolean> {
  const results = await Promise.all([
    validateReference(organizationId, "categories", input.categoryId),
    validateReference(organizationId, "brands", input.brandId),
    validateReference(organizationId, "units", input.unitId),
    validateReference(organizationId, "product_types", input.productTypeId),
  ]);
  return results.every(Boolean);
}

function revalidateProductPaths(productId?: string) {
  revalidatePath(ROUTES.OWNER_PRODUCTS);
  revalidatePath(ROUTES.OWNER_CATALOG_ARCHIVE);
  revalidatePath(ROUTES.OWNER_STOCK_INCOME);
  if (productId) {
    revalidatePath(getOwnerProductRoute(productId));
    revalidatePath(getOwnerProductEditRoute(productId));
  }
}

export async function createProduct(_: CatalogActionState, formData: FormData): Promise<CatalogActionState> {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const input = parseProductInput(formData, dictionary);
  if (!organizationId) return { error: dictionary.catalog.noOrganization };
  if ("error" in input) return input;
  if (!(await validateInputReferences(organizationId, input))) {
    return { error: dictionary.catalog.errors.invalidProductReference };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("products").insert(toPayload(organizationId, input));
  if (error?.code === "23505") return { error: dictionary.catalog.errors.duplicateProductIdentifier };
  if (error) return { error: dictionary.catalog.errors.productCreate };
  revalidateProductPaths();
  redirect(ROUTES.OWNER_PRODUCTS);
}

export async function updateProduct(_: CatalogActionState, formData: FormData): Promise<CatalogActionState> {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const productId = String(formData.get("product_id") ?? "").trim();
  const input = parseProductInput(formData, dictionary);
  if (!organizationId) return { error: dictionary.catalog.noOrganization };
  if (!productId) return { error: dictionary.catalog.errors.missingProduct };
  if ("error" in input) return input;
  if (!(await validateInputReferences(organizationId, input))) {
    return { error: dictionary.catalog.errors.invalidProductReference };
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("products")
    .update(toPayload(organizationId, input))
    .eq("organization_id", organizationId)
    .eq("id", productId)
    .select("id")
    .maybeSingle();
  if (error?.code === "23505") return { error: dictionary.catalog.errors.duplicateProductIdentifier };
  if (error || !data) return { error: dictionary.catalog.errors.productUpdate };
  revalidateProductPaths(productId);
  redirect(getOwnerProductRoute(productId));
}

async function setProductArchiveState(formData: FormData, archived: boolean): Promise<CatalogActionState> {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const productId = String(formData.get("product_id") ?? "").trim();
  if (!organizationId) return { error: dictionary.catalog.noOrganization };
  if (!productId) return { error: dictionary.catalog.errors.missingProduct };

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("products")
    .update({ archived_at: archived ? new Date().toISOString() : null, status: archived ? "inactive" : "active" })
    .eq("organization_id", organizationId)
    .eq("id", productId)
    .is("deleted_at", null)
    .select("id")
    .maybeSingle();
  if (error || !data) return { error: dictionary.catalog.errors.productLifecycle };
  revalidateProductPaths(productId);
  return { error: null, message: archived ? dictionary.catalog.productArchived : dictionary.catalog.productRestored };
}

export async function archiveProduct(_: CatalogActionState, data: FormData) {
  return setProductArchiveState(data, true);
}
export async function restoreProduct(_: CatalogActionState, data: FormData) {
  return setProductArchiveState(data, false);
}
