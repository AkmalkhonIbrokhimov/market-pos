"use client";

import Image from "next/image";
import Link from "next/link";
import { useActionState } from "react";

import { ROUTES } from "@/constants/routes";
import type { Dictionary } from "@/i18n/types";
import { createProduct, updateProduct } from "@/lib/products/actions";
import type {
  CatalogActionState,
  CatalogReference,
  CategoryOption,
  ProductFormValue,
  ProductTypeReference,
  UnitReference,
} from "@/types/catalog";

const INITIAL_STATE: CatalogActionState = { error: null };
const INPUT_CLASS = "mt-2 block w-full border border-slate-300 bg-white px-3 py-2.5 font-normal text-slate-950 outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100";

type ProductFormProps = {
  categories: CategoryOption[];
  brands: CatalogReference[];
  units: UnitReference[];
  productTypes: ProductTypeReference[];
  dictionary: Dictionary;
  product?: ProductFormValue;
};

export function ProductForm({ categories, brands, units, productTypes, dictionary, product }: ProductFormProps) {
  const [state, formAction, isPending] = useActionState(product ? updateProduct : createProduct, INITIAL_STATE);

  return (
    <form action={formAction} className="border border-slate-200 bg-white p-5 sm:p-6">
      {product ? <input type="hidden" name="product_id" value={product.id} /> : null}

      <fieldset>
        <legend className="text-lg font-bold text-slate-950">{dictionary.catalog.basicInformation}</legend>
        <div className="mt-5 grid gap-5 md:grid-cols-2">
          <label className="text-sm font-semibold text-slate-700 md:col-span-2">
            {dictionary.catalog.productName}
            <input required name="name" defaultValue={product?.name} autoComplete="off" className={INPUT_CLASS} />
          </label>
          <label className="text-sm font-semibold text-slate-700">
            {dictionary.common.category}
            <select name="category_id" defaultValue={product?.categoryId ?? ""} className={INPUT_CLASS}>
              <option value="">{dictionary.common.noCategory}</option>
              {categories.map((item) => (
                <option key={item.id} value={item.id} disabled={item.id !== product?.categoryId && (item.status !== "active" || Boolean(item.archivedAt))}>
                  {`${"— ".repeat(item.depth)}${item.name}${item.archivedAt ? ` (${dictionary.catalog.archived})` : ""}`}
                </option>
              ))}
            </select>
          </label>
          <label className="text-sm font-semibold text-slate-700">
            {dictionary.catalog.sku}
            <input name="sku" defaultValue={product?.sku ?? ""} autoComplete="off" className={INPUT_CLASS} />
          </label>
          <label className="text-sm font-semibold text-slate-700">
            {dictionary.common.barcode}
            <input name="barcode" defaultValue={product?.barcode ?? ""} autoComplete="off" className={INPUT_CLASS} />
          </label>
          <label className="text-sm font-semibold text-slate-700">
            {dictionary.catalog.brand}
            <select name="brand_id" defaultValue={product?.brandId ?? ""} className={INPUT_CLASS}>
              <option value="">{dictionary.catalog.noBrand}</option>
              {brands.map((item) => <option key={item.id} value={item.id} disabled={item.id !== product?.brandId && (item.status !== "active" || Boolean(item.archivedAt))}>{item.name}</option>)}
            </select>
          </label>
          <label className="text-sm font-semibold text-slate-700">
            {dictionary.catalog.productType}
            <select name="product_type_id" defaultValue={product?.productTypeId ?? ""} className={INPUT_CLASS}>
              <option value="">{dictionary.catalog.noProductType}</option>
              {productTypes.map((item) => <option key={item.id} value={item.id} disabled={item.id !== product?.productTypeId && (item.status !== "active" || Boolean(item.archivedAt))}>{item.name}</option>)}
            </select>
          </label>
          <label className="text-sm font-semibold text-slate-700">
            {dictionary.catalog.unit}
            <select name="unit_id" defaultValue={product?.unitId ?? ""} className={INPUT_CLASS}>
              <option value="">{dictionary.catalog.useFallbackUnit}</option>
              {units.map((item) => <option key={item.id} value={item.id} disabled={item.id !== product?.unitId && (item.status !== "active" || Boolean(item.archivedAt))}>{item.name} ({item.shortName})</option>)}
            </select>
          </label>
          <label className="text-sm font-semibold text-slate-700">
            {dictionary.catalog.fallbackUnit}
            <input required name="unit" defaultValue={product?.unit ?? "шт"} className={INPUT_CLASS} />
          </label>
          <label className="text-sm font-semibold text-slate-700 md:col-span-2">
            {dictionary.catalog.description}
            <textarea name="description" rows={4} defaultValue={product?.description ?? ""} className={`${INPUT_CLASS} resize-y`} />
          </label>
        </div>
      </fieldset>

      <fieldset className="mt-8 border-t border-slate-200 pt-6">
        <legend className="text-lg font-bold text-slate-950">{dictionary.catalog.pricingAndStock}</legend>
        <div className="mt-5 grid gap-5 md:grid-cols-2">
          <label className="text-sm font-semibold text-slate-700">{dictionary.common.salePrice}<input required name="sale_price" type="number" min="0" step="0.01" defaultValue={product?.salePrice ?? ""} className={INPUT_CLASS} /></label>
          <label className="text-sm font-semibold text-slate-700">{dictionary.common.minimumQuantity}<input required name="min_quantity" type="number" min="0" step="0.001" defaultValue={product?.minQuantity ?? 0} className={INPUT_CLASS} /></label>
          <label className="text-sm font-semibold text-slate-700">{dictionary.common.status}<select name="status" defaultValue={product?.status ?? "active"} className={INPUT_CLASS}><option value="active">{dictionary.common.active}</option><option value="inactive">{dictionary.common.inactive}</option></select></label>
          <label className="flex min-h-11 items-center gap-3 self-end border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm font-semibold text-slate-700"><input name="is_expirable" type="checkbox" defaultChecked={product?.isExpirable ?? false} className="size-4 accent-emerald-700" />{dictionary.catalog.expirable}</label>
        </div>
        <p className="mt-4 text-sm text-slate-500">{dictionary.catalog.quantityNote}</p>
      </fieldset>

      <fieldset className="mt-8 border-t border-slate-200 pt-6">
        <legend className="text-lg font-bold text-slate-950">{dictionary.catalog.dimensions}</legend>
        <div className="mt-5 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          <label className="text-sm font-semibold text-slate-700">{dictionary.catalog.weight}<input name="weight" type="number" min="0" step="0.001" defaultValue={product?.weight ?? ""} className={INPUT_CLASS} /></label>
          <label className="text-sm font-semibold text-slate-700">{dictionary.catalog.weightUnit}<input name="weight_unit" defaultValue={product?.weightUnit ?? "kg"} className={INPUT_CLASS} /></label>
          <label className="text-sm font-semibold text-slate-700">{dictionary.catalog.volume}<input name="volume" type="number" min="0" step="0.001" defaultValue={product?.volume ?? ""} className={INPUT_CLASS} /></label>
          <label className="text-sm font-semibold text-slate-700">{dictionary.catalog.volumeUnit}<input name="volume_unit" defaultValue={product?.volumeUnit ?? "l"} className={INPUT_CLASS} /></label>
          <label className="text-sm font-semibold text-slate-700">{dictionary.catalog.size}<input name="size_text" defaultValue={product?.sizeText ?? ""} className={INPUT_CLASS} /></label>
          <label className="text-sm font-semibold text-slate-700">{dictionary.catalog.color}<input name="color" defaultValue={product?.color ?? ""} className={INPUT_CLASS} /></label>
          <label className="text-sm font-semibold text-slate-700 sm:col-span-2 lg:col-span-3">{dictionary.catalog.packageSize}<input name="package_size" defaultValue={product?.packageSize ?? ""} className={INPUT_CLASS} /></label>
        </div>
      </fieldset>

      <fieldset className="mt-8 border-t border-slate-200 pt-6">
        <legend className="text-lg font-bold text-slate-950">{dictionary.catalog.image}</legend>
        <div className="mt-5 grid gap-5 md:grid-cols-[minmax(0,1fr)_12rem] md:items-start">
          <label className="text-sm font-semibold text-slate-700">{dictionary.catalog.imageUrl}<input name="image_url" type="url" defaultValue={product?.imageUrl ?? ""} placeholder="https://" className={INPUT_CLASS} /><span className="mt-2 block font-normal text-slate-500">{dictionary.catalog.imageUploadLater}</span></label>
          <div className="relative aspect-square overflow-hidden border border-slate-200 bg-slate-100">
            {product?.imageUrl ? <Image src={product.imageUrl} alt={product.name} fill unoptimized className="object-contain" /> : <div className="flex size-full items-center justify-center p-4 text-center text-sm text-slate-500">{dictionary.catalog.imagePlaceholder}</div>}
          </div>
        </div>
      </fieldset>

      {state.error ? <p role="alert" className="mt-5 border-l-4 border-red-500 bg-red-50 p-3 text-sm text-red-800">{state.error}</p> : null}
      <div className="mt-6 flex flex-wrap items-center gap-4 border-t border-slate-200 pt-5">
        <button type="submit" disabled={isPending} className="min-h-11 bg-emerald-700 px-5 py-2.5 text-sm font-bold text-white hover:bg-emerald-800 disabled:opacity-60">{isPending ? dictionary.common.saving : product ? dictionary.catalog.saveProduct : dictionary.catalog.addProduct}</button>
        <Link href={ROUTES.OWNER_PRODUCTS} className="text-sm font-semibold text-slate-600 hover:text-slate-950">{dictionary.common.cancel}</Link>
      </div>
    </form>
  );
}
