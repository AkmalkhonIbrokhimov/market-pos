export type CatalogStatus = "active" | "inactive";

export type Category = {
  id: string;
  name: string;
  status: CatalogStatus;
  parentId: string | null;
  description: string | null;
  sortOrder: number;
  archivedAt: string | null;
  directProductCount: number;
  children: Category[];
};

export type CategoryOption = Omit<Category, "children"> & {
  depth: number;
};

export type CategoryFormValue = Pick<
  Category,
  "id" | "name" | "status" | "parentId" | "description" | "sortOrder" | "archivedAt"
>;

export type Product = {
  id: string;
  name: string;
  categoryId: string | null;
  categoryName: string | null;
  barcode: string | null;
  unit: string;
  salePrice: number;
  currentQuantity: number;
  minQuantity: number;
  isExpirable: boolean;
  status: CatalogStatus;
};

export type ProductFormValue = Omit<Product, "categoryName" | "currentQuantity">;

export type CatalogActionState = {
  error: string | null;
  message?: string | null;
};
