"use client";

import { ArrowRight, Sparkles } from "lucide-react";
import { useI18n } from "@/lib/i18n-context";
import { HERO_IMAGE } from "@/lib/utils";

export function Hero() {
  const { t, locale } = useI18n();
  const isRtl = locale === "ar";

  return (
    <section id="home" className="relative bg-tropical-pattern overflow-hidden">
      <div className="absolute -top-32 start-0 w-96 h-96 bg-brand-200/30 blob blur-3xl pointer-events-none" />
      <div className="absolute -bottom-32 end-0 w-[28rem] h-[28rem] bg-forest-200/30 blob blur-3xl pointer-events-none" />

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-12 pb-16 sm:pt-16 sm:pb-24 lg:pt-24 lg:pb-32">
        <div className="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <div className="text-center lg:text-start animate-fade-in-up">
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-brand-100 text-brand-700 text-xs sm:text-sm font-semibold mb-5">
              <Sparkles className="w-3.5 h-3.5" />
              <span>{t.hero.badge}</span>
            </div>

            <h1 className="font-display text-4xl sm:text-5xl lg:text-6xl xl:text-7xl font-bold text-forest-500 leading-[1.05] tracking-tight">
              {t.hero.title}
            </h1>

            <p className="mt-5 sm:mt-6 text-base sm:text-lg lg:text-xl text-gray-700 leading-relaxed max-w-xl mx-auto lg:mx-0">
              {t.hero.sub}
            </p>

            <div className="mt-8 flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center lg:justify-start">
              <a href="#products" className="group inline-flex items-center justify-center gap-2 px-7 py-4 bg-forest-500 hover:bg-forest-600 text-white font-semibold rounded-full transition-all hover:shadow-lg hover:shadow-forest-500/20">
                {t.hero.cta}
                <ArrowRight className={`w-4 h-4 transition-transform group-hover:translate-x-1 ${isRtl ? "rotate-180 group-hover:-translate-x-1" : ""}`} />
              </a>
              <a href="#about" className="inline-flex items-center justify-center px-7 py-4 border-2 border-forest-500 text-forest-500 hover:bg-forest-500 hover:text-white font-semibold rounded-full transition-colors">
                {t.hero.secondary}
              </a>
            </div>

            <div className="mt-10 flex items-center justify-center lg:justify-start gap-6 sm:gap-8 text-xs sm:text-sm text-gray-600">
              <span className="flex items-center gap-2"><span className="w-2 h-2 rounded-full bg-brand-500" /><span className="font-medium">{t.trust.real}</span></span>
              <span className="flex items-center gap-2"><span className="w-2 h-2 rounded-full bg-forest-500" /><span className="font-medium">{t.trust.no}</span></span>
              <span className="flex items-center gap-2"><span className="w-2 h-2 rounded-full bg-brand-500" /><span className="font-medium">{t.trust.made}</span></span>
            </div>
          </div>

          <div className="relative">
            <div className="relative aspect-[4/5] sm:aspect-[5/6] lg:aspect-[4/5] max-w-md mx-auto lg:max-w-none">
              <div className="absolute inset-4 bg-gradient-to-br from-brand-200 to-brand-400 blob opacity-90" />
              <div className="absolute inset-0 flex items-center justify-center">
                <img src={HERO_IMAGE} alt="Primeroots Tropical Jam" className="relative w-full h-full object-contain drop-shadow-2xl" />
              </div>
              <div className="absolute top-6 end-6 bg-white/95 backdrop-blur-sm rounded-2xl shadow-xl px-4 py-3 border border-brand-100">
                <div className="text-xs text-gray-500 font-medium">{t.hero.new}</div>
                <div className="text-base font-bold text-forest-500">{t.hero.summer}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}