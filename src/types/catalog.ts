export type CatalogStatus = "active" | "inactive";

export type Category = {
  id: string;
  name: string;
  status: CatalogStatus;
};

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
};
