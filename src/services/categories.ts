import { createClient } from "@/lib/supabase/server";
import type { Category, CategoryFormValue, CategoryOption, CatalogStatus } from "@/types/catalog";

type CategoryRow = {
  id: string;
  name: string;
  status: CatalogStatus;
  parent_id: string | null;
  description: string | null;
  sort_order: number;
  archived_at: string | null;
};

function compareCategories(left: Category, right: Category): number {
  return left.sortOrder - right.sortOrder || left.name.localeCompare(right.name);
}

function flattenTree(categories: Category[], depth = 0): CategoryOption[] {
  return categories.flatMap((category) => {
    const { children, ...option } = category;
    return [{ ...option, depth }, ...flattenTree(children, depth + 1)];
  });
}

export async function listCategoryTree(organizationId: string): Promise<Category[]> {
  const supabase = await createClient();
  const [categoriesResult, productsResult] = await Promise.all([
    supabase
      .from("categories")
      .select("id, name, status, parent_id, description, sort_order, archived_at")
      .eq("organization_id", organizationId)
      .order("sort_order")
      .order("name"),
    supabase.from("products").select("category_id").eq("organization_id", organizationId),
  ]);

  if (categoriesResult.error) {
    throw new Error("Unable to load categories.");
  }

  if (productsResult.error) {
    throw new Error("Unable to count category products.");
  }

  const productCounts = new Map<string, number>();
  for (const product of productsResult.data ?? []) {
    if (product.category_id) {
      productCounts.set(product.category_id, (productCounts.get(product.category_id) ?? 0) + 1);
    }
  }

  const categories = new Map<string, Category>();
  for (const row of (categoriesResult.data ?? []) as CategoryRow[]) {
    categories.set(row.id, {
      id: row.id,
      name: row.name,
      status: row.status,
      parentId: row.parent_id,
      description: row.description,
      sortOrder: row.sort_order,
      archivedAt: row.archived_at,
      directProductCount: productCounts.get(row.id) ?? 0,
      children: [],
    });
  }

  const roots: Category[] = [];
  for (const category of categories.values()) {
    const parent = category.parentId ? categories.get(category.parentId) : null;
    if (parent && parent.id !== category.id) {
      parent.children.push(category);
    } else {
      roots.push(category);
    }
  }

  const sortBranch = (branch: Category[]) => {
    branch.sort(compareCategories);
    branch.forEach((category) => sortBranch(category.children));
  };
  sortBranch(roots);

  return roots;
}

export async function listCategoryOptions(
  organizationId: string,
  options: {
    includeInactive?: boolean;
    includeArchived?: boolean;
    excludeBranchId?: string;
  } = {},
): Promise<CategoryOption[]> {
  const tree = await listCategoryTree(organizationId);
  const excludedIds = new Set<string>();

  const collectExcludedBranch = (categories: Category[]) => {
    for (const category of categories) {
      if (category.id === options.excludeBranchId || excludedIds.has(category.parentId ?? "")) {
        excludedIds.add(category.id);
      }
      collectExcludedBranch(category.children);
    }
  };
  collectExcludedBranch(tree);

  return flattenTree(tree).filter(
    (category) =>
      !excludedIds.has(category.id) &&
      (options.includeInactive || category.status === "active") &&
      (options.includeArchived || !category.archivedAt),
  );
}

export async function getCategory(
  organizationId: string,
  categoryId: string,
): Promise<CategoryFormValue | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("categories")
    .select("id, name, status, parent_id, description, sort_order, archived_at")
    .eq("organization_id", organizationId)
    .eq("id", categoryId)
    .maybeSingle();

  if (error) {
    throw new Error("Unable to load the category.");
  }

  if (!data) {
    return null;
  }

  return {
    id: data.id,
    name: data.name,
    status: data.status,
    parentId: data.parent_id,
    description: data.description,
    sortOrder: data.sort_order,
    archivedAt: data.archived_at,
  };
}
