"use client";

import { ShoppingBag, Flame } from "lucide-react";
import { useI18n } from "@/lib/i18n-context";
import { products } from "@/lib/utils";

export function ProductsGrid() {
  const { t } = useI18n();

  return (
    <section id="products" className="py-16 sm:py-20 lg:py-28 bg-cream">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-2xl mx-auto mb-12 lg:mb-16">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-brand-100 text-brand-700 text-xs sm:text-sm font-semibold mb-4">
            <span className="w-1.5 h-1.5 rounded-full bg-brand-500" />
            {t.products.category}
          </div>
          <h2 className="font-display text-3xl sm:text-4xl lg:text-5xl font-bold text-forest-500 leading-tight">{t.products.title}</h2>
          <p className="mt-4 text-base sm:text-lg text-gray-600">{t.products.sub}</p>
        </div>

        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6 lg:gap-8">
          {products.map((p) => {
            const discount = Math.round(((p.original - p.price) / p.original) * 100);
            const name = t.productNames[p.id as keyof typeof t.productNames];
            return (
              <div key={p.id} className="group relative bg-white rounded-3xl overflow-hidden border border-forest-100/60 hover:border-brand-200 transition-all hover:shadow-2xl hover:shadow-forest-500/10 hover:-translate-y-1">
                <div className="absolute top-4 start-4 z-10 inline-flex items-center gap-1 px-2.5 py-1 bg-forest-500 text-white text-xs font-bold rounded-full">
                  <Flame className="w-3 h-3" />-{discount}%
                </div>
                <div className="relative aspect-square bg-gradient-to-br from-cream to-brand-50 overflow-hidden">
                  <img src={p.image} alt={name} className="w-full h-full object-contain p-6 transition-transform duration-500 group-hover:scale-105" />
                </div>
                <div className="p-5 sm:p-6">
                  <div className="text-xs text-brand-600 font-bold uppercase tracking-wider mb-1.5">{t.products.category}</div>
                  <h3 className="font-display text-lg sm:text-xl font-bold text-forest-500 leading-snug min-h-[3rem]">{name}</h3>
                  <div className="mt-4 flex items-baseline gap-2">
                    <span className="text-2xl font-bold text-forest-500">{p.price} <span className="text-sm font-medium text-gray-500">{t.featured.cur}</span></span>
                    <span className="text-sm text-gray-400 line-through">{p.original}</span>
                  </div>
                  <button className="mt-5 w-full inline-flex items-center justify-center gap-2 px-5 py-3 bg-forest-500 hover:bg-forest-600 text-white font-semibold rounded-full transition-colors">
                    <ShoppingBag className="w-4 h-4" />
                    {t.products.addToCart}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}