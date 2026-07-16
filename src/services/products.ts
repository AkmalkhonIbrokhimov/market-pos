import { createClient } from "@/lib/supabase/server";
import type { Product, ProductFormValue } from "@/types/catalog";

type CategoryName = {
  id: string;
  name: string;
};

function mapProduct(
  product: {
    id: string;
    name: string;
    category_id: string | null;
    barcode: string | null;
    unit: string;
    sale_price: number;
    current_quantity: number;
    min_quantity: number;
    is_expirable: boolean;
    status: "active" | "inactive";
  },
  categories: Map<string, string>,
): Product {
  return {
    id: product.id,
    name: product.name,
    categoryId: product.category_id,
    categoryName: product.category_id ? (categories.get(product.category_id) ?? null) : null,
    barcode: product.barcode,
    unit: product.unit,
    salePrice: Number(product.sale_price),
    currentQuantity: Number(product.current_quantity),
    minQuantity: Number(product.min_quantity),
    isExpirable: product.is_expirable,
    status: product.status,
  };
}

export async function listProducts(organizationId: string): Promise<Product[]> {
  const supabase = await createClient();
  const [productsResult, categoriesResult] = await Promise.all([
    supabase
      .from("products")
      .select("id, name, category_id, barcode, unit, sale_price, current_quantity, min_quantity, is_expirable, status")
      .eq("organization_id", organizationId)
      .order("name"),
    supabase.from("categories").select("id, name").eq("organization_id", organizationId),
  ]);

  if (productsResult.error) {
    throw new Error("Unable to load products.");
  }

  if (categoriesResult.error) {
    throw new Error("Unable to load product categories.");
  }

  const categories = new Map(
    ((categoriesResult.data ?? []) as CategoryName[]).map((category) => [category.id, category.name]),
  );

  return (productsResult.data ?? []).map((product) => mapProduct(product, categories));
}

export async function getProduct(
  organizationId: string,
  productId: string,
): Promise<ProductFormValue | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("products")
    .select("id, name, category_id, barcode, unit, sale_price, min_quantity, is_expirable, status")
    .eq("organization_id", organizationId)
    .eq("id", productId)
    .maybeSingle();

  if (error) {
    throw new Error("Unable to load the product.");
  }

  if (!data) {
    return null;
  }

  return {
    id: data.id,
    name: data.name,
    categoryId: data.category_id,
    barcode: data.barcode,
    unit: data.unit,
    salePrice: Number(data.sale_price),
    minQuantity: Number(data.min_quantity),
    isExpirable: data.is_expirable,
    status: data.status,
  };
}
