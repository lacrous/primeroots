"use client";

import { Quote, Star } from "lucide-react";
import { useI18n } from "@/lib/i18n-context";

export function Testimonials() {
  const { t } = useI18n();

  return (
    <section className="py-16 sm:py-20 lg:py-28 bg-gradient-to-b from-cream to-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-2xl mx-auto mb-12 lg:mb-16">
          <h2 className="font-display text-3xl sm:text-4xl lg:text-5xl font-bold text-forest-500 leading-tight">{t.testimonials.title}</h2>
          <p className="mt-4 text-base sm:text-lg text-gray-600">{t.testimonials.sub}</p>
        </div>

        <div className="grid md:grid-cols-3 gap-6 lg:gap-8">
          {t.testimonials.items.map((item, i) => (
            <article key={i} className="group relative bg-white rounded-3xl p-6 sm:p-8 shadow-sm hover:shadow-xl transition-all duration-300 border border-forest-100/60 hover:border-brand-200 hover:-translate-y-1">
              <div className="absolute -top-4 start-6 w-10 h-10 rounded-full bg-brand-500 text-white flex items-center justify-center shadow-lg">
                <Quote className="w-4 h-4 fill-current" />
              </div>
              <div className="flex items-center gap-0.5 mb-4 mt-2 text-brand-500">
                {[...Array(5)].map((_, idx) => (
                  <Star key={idx} className="w-4 h-4 fill-current" />
                ))}
              </div>
              <p className="text-gray-700 leading-relaxed text-sm sm:text-base min-h-[8rem]">&ldquo;{item.t}&rdquo;</p>
              <div className="mt-6 pt-6 border-t border-forest-100 flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-gradient-to-br from-brand-300 to-brand-500 flex items-center justify-center text-white font-bold text-base">{item.n.charAt(0)}</div>
                <div>
                  <div className="font-bold text-forest-500 text-sm sm:text-base">{item.n}</div>
                  <div className="text-xs text-gray-500">{t.testimonials.role}</div>
                </div>
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}