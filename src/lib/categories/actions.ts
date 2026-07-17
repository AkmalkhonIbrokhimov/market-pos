"use server";

import { revalidatePath } from "next/cache";

import { ROUTES, getOwnerCategoryEditRoute } from "@/constants/routes";
import { getDictionary } from "@/i18n/server";
import type { Dictionary } from "@/i18n/types";
import { requireOwnerManager } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";
import type { CatalogActionState, CatalogStatus } from "@/types/catalog";

const VALID_STATUSES: CatalogStatus[] = ["active", "inactive"];

type CategoryInput = {
  name: string;
  parentId: string | null;
  description: string | null;
  sortOrder: number;
  status: CatalogStatus;
};

function parseCategoryInput(
  formData: FormData,
  dictionary: Dictionary,
): CategoryInput | CatalogActionState {
  const name = String(formData.get("name") ?? "").trim();
  const parentId = String(formData.get("parent_id") ?? "").trim() || null;
  const description = String(formData.get("description") ?? "").trim() || null;
  const status = String(formData.get("status") ?? "active") as CatalogStatus;
  const rawSortOrder = String(formData.get("sort_order") ?? "0").trim() || "0";
  const sortOrder = Number(rawSortOrder);

  if (!name) {
    return { error: dictionary.catalog.errors.categoryNameRequired };
  }

  if (!VALID_STATUSES.includes(status)) {
    return { error: dictionary.catalog.errors.invalidCategoryStatus };
  }

  if (!Number.isInteger(sortOrder)) {
    return { error: dictionary.catalog.errors.invalidSortOrder };
  }

  return { name, parentId, description, sortOrder, status };
}

async function isValidParent(
  organizationId: string,
  parentId: string | null,
  categoryId?: string,
): Promise<boolean> {
  if (!parentId) {
    return true;
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("categories")
    .select("id, parent_id, archived_at")
    .eq("organization_id", organizationId);

  if (error) {
    return false;
  }

  const categories = new Map(
    (data ?? []).map((category) => [
      category.id,
      { parentId: category.parent_id as string | null, archivedAt: category.archived_at as string | null },
    ]),
  );
  const parent = categories.get(parentId);

  if (!parent || parent.archivedAt) {
    return false;
  }

  const visited = new Set<string>();
  let ancestorId: string | null = parentId;

  while (ancestorId) {
    if (ancestorId === categoryId || visited.has(ancestorId)) {
      return false;
    }

    visited.add(ancestorId);
    ancestorId = categories.get(ancestorId)?.parentId ?? null;
  }

  return true;
}

function revalidateCategoryPaths(categoryId?: string) {
  revalidatePath(ROUTES.OWNER_CATEGORIES);
  revalidatePath(ROUTES.OWNER_PRODUCTS);
  revalidatePath(ROUTES.OWNER_NEW_PRODUCT);
  if (categoryId) {
    revalidatePath(getOwnerCategoryEditRoute(categoryId));
  }
}

export async function createCategory(
  _previousState: CatalogActionState,
  formData: FormData,
): Promise<CatalogActionState> {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const input = parseCategoryInput(formData, dictionary);

  if (!organizationId) {
    return { error: dictionary.catalog.noOrganization };
  }

  if ("error" in input) {
    return input;
  }

  if (!(await isValidParent(organizationId, input.parentId))) {
    return { error: dictionary.catalog.errors.invalidParentCategory };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("categories").insert({
    organization_id: organizationId,
    name: input.name,
    parent_id: input.parentId,
    description: input.description,
    sort_order: input.sortOrder,
    status: input.status,
  });

  if (error?.code === "23505") {
    return { error: dictionary.catalog.errors.duplicateCategory };
  }

  if (error) {
    return { error: dictionary.catalog.errors.categorySave };
  }

  revalidateCategoryPaths();
  return { error: null, message: dictionary.catalog.categoryCreated };
}

export async function updateCategory(
  _previousState: CatalogActionState,
  formData: FormData,
): Promise<CatalogActionState> {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const categoryId = String(formData.get("category_id") ?? "").trim();
  const input = parseCategoryInput(formData, dictionary);

  if (!organizationId) {
    return { error: dictionary.catalog.noOrganization };
  }

  if (!categoryId) {
    return { error: dictionary.catalog.errors.missingCategory };
  }

  if ("error" in input) {
    return input;
  }

  if (!(await isValidParent(organizationId, input.parentId, categoryId))) {
    return { error: dictionary.catalog.errors.invalidParentCategory };
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("categories")
    .update({
      name: input.name,
      parent_id: input.parentId,
      description: input.description,
      sort_order: input.sortOrder,
      status: input.status,
    })
    .eq("organization_id", organizationId)
    .eq("id", categoryId)
    .select("id")
    .maybeSingle();

  if (error?.code === "23505") {
    return { error: dictionary.catalog.errors.duplicateCategory };
  }

  if (error || !data) {
    return { error: dictionary.catalog.errors.categoryUpdate };
  }

  revalidateCategoryPaths(categoryId);
  return { error: null, message: dictionary.catalog.categoryUpdated };
}

async function updateCategoryLifecycle(
  formData: FormData,
  mode: "deactivate" | "archive" | "restore",
): Promise<CatalogActionState> {
  const [currentUser, dictionary] = await Promise.all([requireOwnerManager(), getDictionary()]);
  const organizationId = currentUser.profile.organizationId;
  const categoryId = String(formData.get("category_id") ?? "").trim();

  if (!organizationId) {
    return { error: dictionary.catalog.noOrganization };
  }

  if (!categoryId) {
    return { error: dictionary.catalog.errors.missingCategory };
  }

  const supabase = await createClient();

  if (mode === "archive") {
    const { data: descendants, error: childrenError } = await supabase
      .from("categories")
      .select("id, parent_id, status, archived_at")
      .eq("organization_id", organizationId);

    if (childrenError) {
      return { error: dictionary.catalog.errors.categoryLifecycle };
    }

    const childrenByParent = new Map<string, typeof descendants>();
    for (const category of descendants ?? []) {
      if (category.parent_id) {
        const siblings = childrenByParent.get(category.parent_id) ?? [];
        siblings.push(category);
        childrenByParent.set(category.parent_id, siblings);
      }
    }

    const pendingParents = [categoryId];
    let hasActiveDescendant = false;
    while (pendingParents.length > 0 && !hasActiveDescendant) {
      const parentId = pendingParents.pop();
      for (const child of parentId ? (childrenByParent.get(parentId) ?? []) : []) {
        if (child.status === "active" && !child.archived_at) {
          hasActiveDescendant = true;
          break;
        }
        pendingParents.push(child.id);
      }
    }

    if (hasActiveDescendant) {
      return { error: dictionary.catalog.cannotArchiveActiveSubcategories };
    }
  }

  const payload =
    mode === "archive"
      ? { archived_at: new Date().toISOString(), status: "inactive" as const }
      : mode === "restore"
        ? { archived_at: null, status: "active" as const }
        : { status: "inactive" as const };

  const { data, error } = await supabase
    .from("categories")
    .update(payload)
    .eq("organization_id", organizationId)
    .eq("id", categoryId)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    return { error: dictionary.catalog.errors.categoryLifecycle };
  }

  revalidateCategoryPaths(categoryId);
  const message =
    mode === "archive"
      ? dictionary.catalog.categoryArchived
      : mode === "restore"
        ? dictionary.catalog.categoryRestored
        : dictionary.catalog.categoryDeactivated;

  return { error: null, message };
}

export async function deactivateCategory(
  _previousState: CatalogActionState,
  formData: FormData,
): Promise<CatalogActionState> {
  return updateCategoryLifecycle(formData, "deactivate");
}

export async function archiveCategory(
  _previousState: CatalogActionState,
  formData: FormData,
): Promise<CatalogActionState> {
  return updateCategoryLifecycle(formData, "archive");
}

export async function restoreCategory(
  _previousState: CatalogActionState,
  formData: FormData,
): Promise<CatalogActionState> {
  return updateCategoryLifecycle(formData, "restore");
}
