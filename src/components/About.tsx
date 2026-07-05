"use client";

import { Sparkles, Leaf, ShieldCheck, Heart } from "lucide-react";
import { useI18n } from "@/lib/i18n-context";

const icons = [Leaf, ShieldCheck, Heart];

export function About() {
  const { t } = useI18n();
  const features = [
    { title: t.about.f1t, desc: t.about.f1d },
    { title: t.about.f2t, desc: t.about.f2d },
    { title: t.about.f3t, desc: t.about.f3d },
  ];

  return (
    <section id="about" className="py-16 sm:py-20 lg:py-28 bg-white relative overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-10 lg:gap-20 items-center">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-forest-100 text-forest-500 text-xs sm:text-sm font-semibold mb-5">
              <Sparkles className="w-3.5 h-3.5" />
              {t.about.eyebrow}
            </div>
            <h2 className="font-display text-3xl sm:text-4xl lg:text-5xl font-bold text-forest-500 leading-tight">{t.about.title}</h2>
            <p className="mt-5 text-base sm:text-lg text-gray-700 leading-relaxed">{t.about.p1}</p>
            <p className="mt-4 text-base sm:text-lg text-gray-700 leading-relaxed">{t.about.p2}</p>
          </div>

          <div className="grid sm:grid-cols-2 gap-4 sm:gap-5">
            {features.map((f, i) => {
              const Icon = icons[i];
              return (
                <div key={i} className="group bg-cream hover:bg-brand-50 rounded-3xl p-6 sm:p-7 border border-forest-100 hover:border-brand-200 transition-all hover:-translate-y-1 hover:shadow-lg">
                  <div className="w-12 h-12 rounded-2xl bg-forest-500 group-hover:bg-brand-500 flex items-center justify-center text-white transition-colors mb-4">
                    <Icon className="w-6 h-6" />
                  </div>
                  <h3 className="font-display text-lg font-bold text-forest-500">{f.title}</h3>
                  <p className="mt-2 text-sm text-gray-600 leading-relaxed">{f.desc}</p>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}