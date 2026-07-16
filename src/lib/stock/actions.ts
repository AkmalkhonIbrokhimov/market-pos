"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { ROUTES } from "@/constants/routes";
import { getDictionary } from "@/i18n/server";
import type { Dictionary } from "@/i18n/types";
import { requireOwnerManager } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";
import type { StockActionState } from "@/types/stock";

function parseNumber(value: FormDataEntryValue | null): number | null {
  const rawValue = String(value ?? "").trim();
  const parsedValue = Number(rawValue);

  return rawValue !== "" && Number.isFinite(parsedValue) ? parsedValue : null;
}

function isValidIsoDate(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);

  if (!match) {
    return false;
  }

  const date = new Date(`${value}T00:00:00Z`);

  return (
    date.getUTCFullYear() === Number(match[1]) &&
    date.getUTCMonth() + 1 === Number(match[2]) &&
    date.getUTCDate() === Number(match[3])
  );
}

function getReceivedDate(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Tashkent",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function validateInput(
  formData: FormData,
  dictionary: Dictionary,
):
  | {
      storeId: string;
      productId: string;
      supplierId: string | null;
      quickSupplierName: string;
      quantity: number;
      purchasePrice: number;
      salePriceAtArrival: number | null;
      expirationDate: string | null;
      comment: string | null;
    }
  | StockActionState {
  const storeId = String(formData.get("store_id") ?? "").trim();
  const productId = String(formData.get("product_id") ?? "").trim();
  const supplierId = String(formData.get("supplier_id") ?? "").trim() || null;
  const quickSupplierName = String(formData.get("quick_supplier_name") ?? "").trim();
  const quantity = parseNumber(formData.get("quantity"));
  const purchasePrice = parseNumber(formData.get("purchase_price"));
  const salePriceAtArrival = parseNumber(formData.get("sale_price_at_arrival"));
  const expirationDate = String(formData.get("expiration_date") ?? "").trim() || null;
  const comment = String(formData.get("comment") ?? "").trim() || null;

  if (!storeId) {
    return { error: dictionary.stock.errors.storeRequired };
  }

  if (!productId) {
    return { error: dictionary.stock.errors.productRequired };
  }

  if (quantity === null || quantity <= 0) {
    return { error: dictionary.stock.errors.quantityInvalid };
  }

  if (purchasePrice === null || purchasePrice < 0) {
    return { error: dictionary.stock.errors.purchasePriceInvalid };
  }

  if (salePriceAtArrival !== null && salePriceAtArrival < 0) {
    return { error: dictionary.stock.errors.salePriceInvalid };
  }

  if (expirationDate && !isValidIsoDate(expirationDate)) {
    return { error: dictionary.stock.errors.expirationDateInvalid };
  }

  if (supplierId && quickSupplierName) {
    return { error: dictionary.stock.errors.supplierConflict };
  }

  return {
    storeId,
    productId,
    supplierId,
    quickSupplierName,
    quantity: Number(quantity.toFixed(3)),
    purchasePrice: Number(purchasePrice.toFixed(2)),
    salePriceAtArrival:
      salePriceAtArrival === null ? null : Number(salePriceAtArrival.toFixed(2)),
    expirationDate,
    comment,
  };
}

export async function addStockIncome(
  _previousState: StockActionState,
  formData: FormData,
): Promise<StockActionState> {
  const [currentUser, dictionary] = await Promise.all([
    requireOwnerManager(),
    getDictionary(),
  ]);
  const organizationId = currentUser.profile.organizationId;
  const input = validateInput(formData, dictionary);

  if (!organizationId) {
    return { error: dictionary.stock.errors.noOrganization };
  }

  if ("error" in input) {
    return input;
  }

  const supabase = await createClient();
  const [storeAccessResult, storeResult, productResult] = await Promise.all([
    supabase
      .from("user_store_access")
      .select("id")
      .eq("user_id", currentUser.profile.id)
      .eq("store_id", input.storeId)
      .maybeSingle(),
    supabase
      .from("stores")
      .select("id, organization_id")
      .eq("id", input.storeId)
      .eq("organization_id", organizationId)
      .maybeSingle(),
    supabase
      .from("products")
      .select("id, sale_price, current_quantity")
      .eq("id", input.productId)
      .eq("organization_id", organizationId)
      .eq("status", "active")
      .maybeSingle(),
  ]);

  if (storeAccessResult.error || storeResult.error || !storeAccessResult.data || !storeResult.data) {
    return { error: dictionary.stock.errors.storeAccess };
  }

  if (productResult.error || !productResult.data) {
    return { error: dictionary.stock.errors.productAccess };
  }

  let supplierId = input.supplierId;

  if (supplierId) {
    const { data: supplier, error: supplierError } = await supabase
      .from("suppliers")
      .select("id")
      .eq("id", supplierId)
      .eq("organization_id", organizationId)
      .eq("status", "active")
      .maybeSingle();

    if (supplierError || !supplier) {
      return { error: dictionary.stock.errors.supplierAccess };
    }
  } else if (input.quickSupplierName) {
    const { data: supplier, error: supplierError } = await supabase
      .from("suppliers")
      .insert({
        organization_id: organizationId,
        name: input.quickSupplierName,
        status: "active",
      })
      .select("id")
      .single();

    if (supplierError || !supplier) {
      return { error: dictionary.stock.errors.supplierCreate };
    }

    supplierId = supplier.id;
  }

  const oldQuantity = Number(productResult.data.current_quantity);
  const newQuantity = Number((oldQuantity + input.quantity).toFixed(3));
  const salePriceAtArrival =
    input.salePriceAtArrival ?? Number(productResult.data.sale_price);

  const { data: batch, error: batchError } = await supabase
    .from("product_batches")
    .insert({
      store_id: input.storeId,
      product_id: input.productId,
      supplier_id: supplierId,
      received_date: getReceivedDate(),
      initial_quantity: input.quantity,
      remaining_quantity: input.quantity,
      purchase_price: input.purchasePrice,
      sale_price_at_arrival: salePriceAtArrival,
      expiration_date: input.expirationDate,
      comment: input.comment,
      created_by: currentUser.profile.id,
    })
    .select("id")
    .single();

  if (batchError || !batch) {
    return { error: dictionary.stock.errors.batchCreate };
  }

  const { data: updatedProduct, error: quantityError } = await supabase
    .from("products")
    .update({ current_quantity: newQuantity })
    .eq("id", input.productId)
    .eq("organization_id", organizationId)
    .eq("current_quantity", oldQuantity)
    .select("id")
    .maybeSingle();

  if (quantityError) {
    return { error: dictionary.stock.errors.quantityUpdatePartial };
  }

  if (!updatedProduct) {
    return { error: dictionary.stock.errors.quantityConflictPartial };
  }

  const { error: movementError } = await supabase.from("stock_movements").insert({
    store_id: input.storeId,
    product_id: input.productId,
    batch_id: batch.id,
    type: "income",
    quantity: input.quantity,
    old_quantity: oldQuantity,
    new_quantity: newQuantity,
    reason: "income",
    comment: input.comment,
    created_by: currentUser.profile.id,
  });

  if (movementError) {
    return { error: dictionary.stock.errors.movementCreatePartial };
  }

  revalidatePath(ROUTES.OWNER_PRODUCTS);
  revalidatePath(ROUTES.OWNER_STOCK_INCOME);
  revalidatePath(ROUTES.OWNER_STOCK_INCOME_HISTORY);
  redirect(`${ROUTES.OWNER_STOCK_INCOME_HISTORY}?created=1`);
}
