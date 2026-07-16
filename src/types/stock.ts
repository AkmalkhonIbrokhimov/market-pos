export type StockStore = {
  id: string;
  name: string;
};

export type StockProduct = {
  id: string;
  name: string;
  barcode: string | null;
  unit: string;
  salePrice: number;
  currentQuantity: number;
};

export type Supplier = {
  id: string;
  name: string;
};

export type IncomeHistoryRecord = {
  id: string;
  receivedDate: string;
  productName: string;
  productBarcode: string | null;
  supplierName: string | null;
  initialQuantity: number;
  remainingQuantity: number;
  purchasePrice: number;
  salePriceAtArrival: number;
  expirationDate: string | null;
  comment: string | null;
};

export type StockActionState = {
  error: string | null;
};
