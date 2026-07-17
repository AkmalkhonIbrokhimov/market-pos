import { createClient } from "@/lib/supabase/server";
import type { CatalogStatus, Product } from "@/types/catalog";

type ProductRow = {
  id: string;
  name: string;
  category_id: string | null;
  sku: string | null;
  barcode: string | null;
  brand_id: string | null;
  product_type_id: string | null;
  unit_id: string | null;
  unit: string;
  sale_price: number;
  current_quantity: number;
  min_quantity: number;
  is_expirable: boolean;
  status: CatalogStatus;
  description: string | null;
  image_url: string | null;
  weight: number | null;
  weight_unit: string | null;
  volume: number | null;
  volume_unit: string | null;
  size_text: string | null;
  color: string | null;
  package_size: string | null;
  archived_at: string | null;
  deleted_at: string | null;
};

type CategoryRow = { id: string; name: string; parent_id: string | null };

function buildCategoryNames(rows: CategoryRow[]): Map<string, string> {
  const categories = new Map(rows.map((item) => [item.id, item]));
  const names = new Map<string, string>();

  for (const category of rows) {
    const path: string[] = [];
    const visited = new Set<string>();
    let current: CategoryRow | undefined = category;
    while (current && !visited.has(current.id)) {
      path.unshift(current.name);
      visited.add(current.id);
      current = current.parent_id ? categories.get(current.parent_id) : undefined;
    }
    names.set(category.id, path.join(" / "));
  }

  return names;
}

async function loadProducts(organizationId: string, productId?: string): Promise<Product[]> {
  const supabase = await createClient();
  let productsQuery = supabase
    .from("products")
    .select("id, name, category_id, sku, barcode, brand_id, product_type_id, unit_id, unit, sale_price, current_quantity, min_quantity, is_expirable, status, description, image_url, weight, weight_unit, volume, volume_unit, size_text, color, package_size, archived_at, deleted_at")
    .eq("organization_id", organizationId)
    .is("deleted_at", null)
    .order("name");

  if (productId) productsQuery = productsQuery.eq("id", productId);

  const [productsResult, categoriesResult, brandsResult, unitsResult, typesResult] = await Promise.all([
    productsQuery,
    supabase.from("categories").select("id, name, parent_id").eq("organization_id", organizationId),
    supabase.from("brands").select("id, name").eq("organization_id", organizationId),
    supabase.from("units").select("id, name, short_name").eq("organization_id", organizationId),
    supabase.from("product_types").select("id, name").eq("organization_id", organizationId),
  ]);

  if (productsResult.error) throw new Error("Unable to load products.");
  if (categoriesResult.error || brandsResult.error || unitsResult.error || typesResult.error) {
    throw new Error("Unable to load product reference data.");
  }

  const categoryNames = buildCategoryNames((categoriesResult.data ?? []) as CategoryRow[]);
  const brands = new Map((brandsResult.data ?? []).map((item) => [item.id, item.name]));
  const units = new Map((unitsResult.data ?? []).map((item) => [item.id, item.short_name || item.name]));
  const productTypes = new Map((typesResult.data ?? []).map((item) => [item.id, item.name]));

  return ((productsResult.data ?? []) as ProductRow[]).map((product) => ({
    id: product.id,
    name: product.name,
    categoryId: product.category_id,
    categoryName: product.category_id ? (categoryNames.get(product.category_id) ?? null) : null,
    sku: product.sku,
    barcode: product.barcode,
    brandId: product.brand_id,
    brandName: product.brand_id ? (brands.get(product.brand_id) ?? null) : null,
    productTypeId: product.product_type_id,
    productTypeName: product.product_type_id ? (productTypes.get(product.product_type_id) ?? null) : null,
    unitId: product.unit_id,
    unit: product.unit,
    unitName: product.unit_id ? (units.get(product.unit_id) ?? product.unit) : product.unit,
    salePrice: Number(product.sale_price),
    currentQuantity: Number(product.current_quantity),
    minQuantity: Number(product.min_quantity),
    isExpirable: product.is_expirable,
    status: product.status,
    description: product.description,
    imageUrl: product.image_url,
    weight: product.weight === null ? null : Number(product.weight),
    weightUnit: product.weight_unit,
    volume: product.volume === null ? null : Number(product.volume),
    volumeUnit: product.volume_unit,
    sizeText: product.size_text,
    color: product.color,
    packageSize: product.package_size,
    archivedAt: product.archived_at,
    deletedAt: product.deleted_at,
  }));
}

export async function listProducts(organizationId: string): Promise<Product[]> {
  return loadProducts(organizationId);
}

export async function getProduct(organizationId: string, productId: string): Promise<Product | null> {
  return (await loadProducts(organizationId, productId))[0] ?? null;
}
