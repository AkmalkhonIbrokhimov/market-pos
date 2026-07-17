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
  sku: string | null;
  barcode: string | null;
  brandId: string | null;
  brandName: string | null;
  productTypeId: string | null;
  productTypeName: string | null;
  unitId: string | null;
  unit: string;
  unitName: string;
  salePrice: number;
  currentQuantity: number;
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
  archivedAt: string | null;
  deletedAt: string | null;
};

export type ProductFormValue = Omit<
  Product,
  "categoryName" | "brandName" | "productTypeName" | "unitName" | "currentQuantity"
>;

export type CatalogReference = {
  id: string;
  name: string;
  description: string | null;
  status: CatalogStatus;
  archivedAt: string | null;
};

export type UnitReference = Omit<CatalogReference, "description"> & {
  shortName: string;
};

export type ProductTypeReference = CatalogReference & {
  code: string | null;
};

export type CatalogActionState = {
  error: string | null;
  message?: string | null;
};
