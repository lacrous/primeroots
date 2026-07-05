"use client";

import { Check, Star } from "lucide-react";
import { useI18n } from "@/lib/i18n-context";
import { FEATURED_IMAGE } from "@/lib/utils";

export function FeaturedProduct() {
  const { t } = useI18n();
  return (
    <section className="py-16 sm:py-20 lg:py-28 bg-gradient-to-br from-forest-500 via-forest-600 to-forest-700 text-white relative overflow-hidden">
      <div className="absolute top-0 start-0 w-full h-full opacity-10 pointer-events-none">
        <div className="absolute top-10 start-10 w-32 h-32 rounded-full border-2 border-brand-400" />
        <div className="absolute bottom-20 end-20 w-48 h-48 rounded-full border-2 border-brand-400" />
        <div className="absolute top-1/2 start-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 rounded-full border border-brand-400/30" />
      </div>

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <div className="order-2 lg:order-1">
            <div className="relative aspect-square max-w-md mx-auto">
              <div className="absolute inset-0 bg-gradient-to-br from-brand-300/40 to-brand-600/40 blob" />
              <img src={FEATURED_IMAGE} alt={t.featured.name} className="relative w-full h-full object-contain drop-shadow-2xl" />
            </div>
          </div>

          <div className="order-1 lg:order-2 text-center lg:text-start">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-brand-500 text-forest-900 text-xs sm:text-sm font-bold mb-5">
              <Star className="w-3.5 h-3.5 fill-current" />
              {t.featured.eyebrow}
            </div>
            <h2 className="font-display text-3xl sm:text-4xl lg:text-5xl font-bold leading-tight">{t.featured.title}</h2>
            <h3 className="mt-3 text-lg sm:text-xl font-semibold text-brand-200">{t.featured.name}</h3>
            <p className="mt-5 text-base sm:text-lg text-white/85 leading-relaxed max-w-xl mx-auto lg:mx-0">{t.featured.desc}</p>

            <div className="mt-6">
              <div className="text-xs uppercase tracking-wider text-brand-300 font-bold mb-3">{t.featured.boxLabel}</div>
              <ul className="flex flex-wrap gap-2 justify-center lg:justify-start">
                {t.featured.flavors.map((f, i) => (
                  <li key={i} className="px-3 py-1.5 rounded-full bg-white/10 backdrop-blur-sm border border-white/20 text-sm font-medium">{f}</li>
                ))}
              </ul>
            </div>

            <ul className="mt-6 space-y-2 text-sm sm:text-base">
              {t.featured.features.map((f, i) => (
                <li key={i} className="flex items-center gap-2 justify-center lg:justify-start">
                  <Check className="w-4 h-4 text-brand-300 flex-shrink-0" />
                  <span className="text-white/90">{f}</span>
                </li>
              ))}
            </ul>

            <div className="mt-8 flex flex-col sm:flex-row items-center gap-4 justify-center lg:justify-start">
              <div className="flex items-baseline gap-3">
                <span className="text-3xl sm:text-4xl font-bold text-brand-300">699 {t.featured.cur}</span>
                <span className="text-base sm:text-lg text-white/50 line-through">800</span>
              </div>
              <a href="#products" className="inline-flex items-center justify-center px-7 py-3.5 bg-brand-500 hover:bg-brand-600 text-forest-900 font-bold rounded-full transition-colors shadow-lg">
                {t.featured.cta}
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}