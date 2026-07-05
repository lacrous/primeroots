"use client";

import { useState } from "react";
import { Plus, Minus } from "lucide-react";
import { useI18n } from "@/lib/i18n-context";

export function FAQ() {
  const { t } = useI18n();
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <section id="faq" className="py-16 sm:py-20 lg:py-28 bg-white">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-12 lg:mb-16">
          <h2 className="font-display text-3xl sm:text-4xl lg:text-5xl font-bold text-forest-500 leading-tight">{t.faq.title}</h2>
          <p className="mt-4 text-base sm:text-lg text-gray-600">{t.faq.sub}</p>
        </div>

        <div className="space-y-3 sm:space-y-4">
          {t.faq.items.map((item, i) => {
            const isOpen = openIndex === i;
            return (
              <div key={i} className={`rounded-2xl border transition-all overflow-hidden ${isOpen ? "bg-cream border-brand-200 shadow-md" : "bg-white border-forest-100 hover:border-brand-200"}`}>
                <button
                  type="button"
                  onClick={() => setOpenIndex(isOpen ? null : i)}
                  className="w-full flex items-center justify-between gap-4 px-5 sm:px-6 py-5 text-start"
                  aria-expanded={isOpen}
                >
                  <h3 className="font-display text-base sm:text-lg lg:text-xl font-bold text-forest-500 leading-snug">{item.q}</h3>
                  <div className={`flex-shrink-0 w-9 h-9 rounded-full flex items-center justify-center transition-colors ${isOpen ? "bg-brand-500 text-white" : "bg-forest-100 text-forest-500"}`}>
                    {isOpen ? <Minus className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
                  </div>
                </button>
                <div className={`grid transition-all duration-300 ease-in-out ${isOpen ? "grid-rows-[1fr] opacity-100" : "grid-rows-[0fr] opacity-0"}`}>
                  <div className="overflow-hidden">
                    <div className="px-5 sm:px-6 pb-5 text-sm sm:text-base text-gray-700 leading-relaxed">{item.a}</div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}