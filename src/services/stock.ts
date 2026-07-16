import { createClient } from "@/lib/supabase/server";
import type { IncomeHistoryRecord, StockProduct, StockStore } from "@/types/stock";

type ProductReference = {
  id: string;
  name: string;
  barcode: string | null;
};

type SupplierReference = {
  id: string;
  name: string;
};

export async function listAccessibleStores(userId: string): Promise<StockStore[]> {
  const supabase = await createClient();
  const { data: accessRecords, error: accessError } = await supabase
    .from("user_store_access")
    .select("store_id")
    .eq("user_id", userId);

  if (accessError) {
    throw new Error("Unable to load store access.");
  }

  const storeIds = (accessRecords ?? []).map((record) => record.store_id);

  if (storeIds.length === 0) {
    return [];
  }

  const { data, error } = await supabase
    .from("stores")
    .select("id, name")
    .in("id", storeIds)
    .eq("status", "active")
    .order("name");

  if (error) {
    throw new Error("Unable to load stores.");
  }

  return data ?? [];
}

export async function listStockProducts(organizationId: string): Promise<StockProduct[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("products")
    .select("id, name, barcode, unit, sale_price, current_quantity")
    .eq("organization_id", organizationId)
    .eq("status", "active")
    .order("name");

  if (error) {
    throw new Error("Unable to load products for stock income.");
  }

  return (data ?? []).map((product) => ({
    id: product.id,
    name: product.name,
    barcode: product.barcode,
    unit: product.unit,
    salePrice: Number(product.sale_price),
    currentQuantity: Number(product.current_quantity),
  }));
}

export async function listIncomeHistory(storeIds: string[]): Promise<IncomeHistoryRecord[]> {
  if (storeIds.length === 0) {
    return [];
  }

  const supabase = await createClient();
  const { data: batches, error: batchesError } = await supabase
    .from("product_batches")
    .select(
      "id, product_id, supplier_id, received_date, initial_quantity, remaining_quantity, purchase_price, sale_price_at_arrival, expiration_date, comment, created_at",
    )
    .in("store_id", storeIds)
    .order("created_at", { ascending: false })
    .limit(200);

  if (batchesError) {
    throw new Error("Unable to load income history.");
  }

  const productIds = [...new Set((batches ?? []).map((batch) => batch.product_id))];
  const supplierIds = [
    ...new Set(
      (batches ?? [])
        .map((batch) => batch.supplier_id)
        .filter((supplierId): supplierId is string => Boolean(supplierId)),
    ),
  ];

  const [productsResult, suppliersResult] = await Promise.all([
    productIds.length > 0
      ? supabase.from("products").select("id, name, barcode").in("id", productIds)
      : Promise.resolve({ data: [] as ProductReference[], error: null }),
    supplierIds.length > 0
      ? supabase.from("suppliers").select("id, name").in("id", supplierIds)
      : Promise.resolve({ data: [] as SupplierReference[], error: null }),
  ]);

  if (productsResult.error) {
    throw new Error("Unable to load products for income history.");
  }

  if (suppliersResult.error) {
    throw new Error("Unable to load suppliers for income history.");
  }

  const products = new Map(
    (productsResult.data ?? []).map((product) => [product.id, product] as const),
  );
  const suppliers = new Map(
    (suppliersResult.data ?? []).map((supplier) => [supplier.id, supplier.name] as const),
  );

  return (batches ?? []).map((batch) => {
    const product = products.get(batch.product_id);

    return {
      id: batch.id,
      receivedDate: batch.received_date,
      productName: product?.name ?? "-",
      productBarcode: product?.barcode ?? null,
      supplierName: batch.supplier_id ? (suppliers.get(batch.supplier_id) ?? null) : null,
      initialQuantity: Number(batch.initial_quantity),
      remainingQuantity: Number(batch.remaining_quantity),
      purchasePrice: Number(batch.purchase_price),
      salePriceAtArrival: Number(batch.sale_price_at_arrival),
      expirationDate: batch.expiration_date,
      comment: batch.comment,
    };
  });
}
