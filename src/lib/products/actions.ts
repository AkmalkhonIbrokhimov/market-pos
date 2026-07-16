"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { ROUTES, getOwnerProductEditRoute } from "@/constants/routes";
import { requireOwnerManager } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";
import type { CatalogActionState, CatalogStatus } from "@/types/catalog";

const VALID_STATUSES: CatalogStatus[] = ["active", "inactive"];

type ProductInput = {
  name: string;
  categoryId: string | null;
  barcode: string | null;
  unit: string;
  salePrice: number;
  minQuantity: number;
  isExpirable: boolean;
  status: CatalogStatus;
};

function parseNonNegativeNumber(value: FormDataEntryValue | null): number | null {
  const rawValue = String(value ?? "").trim();
  const parsedValue = Number(rawValue);

  return rawValue !== "" && Number.isFinite(parsedValue) && parsedValue >= 0
    ? parsedValue
    : null;
}

function parseProductInput(formData: FormData): ProductInput | CatalogActionState {
  const name = String(formData.get("name") ?? "").trim();
  const barcode = String(formData.get("barcode") ?? "").trim() || null;
  const unit = String(formData.get("unit") ?? "").trim() || "шт";
  const categoryId = String(formData.get("category_id") ?? "").trim() || null;
  const salePrice = parseNonNegativeNumber(formData.get("sale_price"));
  const minQuantity = parseNonNegativeNumber(formData.get("min_quantity"));
  const status = String(formData.get("status") ?? "active") as CatalogStatus;

  if (!name) {
    return { error: "Product name is required." };
  }

  if (salePrice === null) {
    return { error: "Sale price is required and must be zero or greater." };
  }

  if (minQuantity === null) {
    return { error: "Minimum quantity must be zero or greater." };
  }

  if (!VALID_STATUSES.includes(status)) {
    return { error: "Choose a valid product status." };
  }

  return {
    name,
    categoryId,
    barcode,
    unit,
    salePrice,
    minQuantity,
    isExpirable: formData.get("is_expirable") === "on",
    status,
  };
}

async function validateCategory(
  organizationId: string,
  categoryId: string | null,
): Promise<boolean> {
  if (!categoryId) {
    return true;
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("categories")
    .select("id")
    .eq("organization_id", organizationId)
    .eq("id", categoryId)
    .maybeSingle();

  return !error && Boolean(data);
}

function toProductPayload(organizationId: string, input: ProductInput) {
  return {
    organization_id: organizationId,
    category_id: input.categoryId,
    name: input.name,
    barcode: input.barcode,
    unit: input.unit,
    sale_price: input.salePrice,
    min_quantity: input.minQuantity,
    is_expirable: input.isExpirable,
    status: input.status,
  };
}

export async function createProduct(
  _previousState: CatalogActionState,
  formData: FormData,
): Promise<CatalogActionState> {
  const currentUser = await requireOwnerManager();
  const organizationId = currentUser.profile.organizationId;
  const input = parseProductInput(formData);

  if (!organizationId) {
    return { error: "Your user profile is not assigned to an organization." };
  }

  if ("error" in input) {
    return input;
  }

  if (!(await validateCategory(organizationId, input.categoryId))) {
    return { error: "Choose a category from your organization." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("products")
    .insert(toProductPayload(organizationId, input));

  if (error?.code === "23505") {
    return { error: "A product with this barcode already exists." };
  }

  if (error) {
    return { error: "Unable to add the product. Please try again." };
  }

  revalidatePath(ROUTES.OWNER_PRODUCTS);
  redirect(ROUTES.OWNER_PRODUCTS);
}

export async function updateProduct(
  _previousState: CatalogActionState,
  formData: FormData,
): Promise<CatalogActionState> {
  const currentUser = await requireOwnerManager();
  const organizationId = currentUser.profile.organizationId;
  const productId = String(formData.get("product_id") ?? "").trim();
  const input = parseProductInput(formData);

  if (!organizationId) {
    return { error: "Your user profile is not assigned to an organization." };
  }

  if (!productId) {
    return { error: "The product could not be identified." };
  }

  if ("error" in input) {
    return input;
  }

  if (!(await validateCategory(organizationId, input.categoryId))) {
    return { error: "Choose a category from your organization." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("products")
    .update(toProductPayload(organizationId, input))
    .eq("organization_id", organizationId)
    .eq("id", productId)
    .select("id")
    .maybeSingle();

  if (error?.code === "23505") {
    return { error: "A product with this barcode already exists." };
  }

  if (error) {
    return { error: "Unable to update the product. Please try again." };
  }

  if (!data) {
    return { error: "Product not found or access was denied." };
  }

  revalidatePath(ROUTES.OWNER_PRODUCTS);
  revalidatePath(getOwnerProductEditRoute(productId));
  redirect(ROUTES.OWNER_PRODUCTS);
}
