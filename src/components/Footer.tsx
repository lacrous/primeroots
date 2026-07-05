"use client";

import { ArrowUp } from "lucide-react";
import { useI18n } from "@/lib/i18n-context";
import { LOGO_LIGHT } from "@/lib/utils";

const FacebookIcon = (props: React.SVGProps<SVGSVGElement>) => (
  <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
    <path d="M22 12c0-5.523-4.477-10-10-10S2 6.477 2 12c0 4.991 3.657 9.128 8.438 9.878v-6.987h-2.54V12h2.54V9.797c0-2.506 1.492-3.89 3.777-3.89 1.094 0 2.238.195 2.238.195v2.46h-1.26c-1.243 0-1.63.771-1.63 1.562V12h2.773l-.443 2.89h-2.33v6.988C18.343 21.128 22 16.991 22 12z" />
  </svg>
);
const InstagramIcon = (props: React.SVGProps<SVGSVGElement>) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
    <rect x="2" y="2" width="20" height="20" rx="5" ry="5" />
    <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z" />
    <line x1="17.5" y1="6.5" x2="17.51" y2="6.5" />
  </svg>
);
const WhatsappIcon = (props: React.SVGProps<SVGSVGElement>) => (
  <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
    <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448L.057 24zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413z" />
  </svg>
);

export function Footer() {
  const { t } = useI18n();

  return (
    <footer className="bg-forest-500 text-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div className="grid md:grid-cols-3 gap-10 lg:gap-16">
          <div>
            <a href="#home" aria-label="Primeroots">
              <img src={LOGO_LIGHT} alt="Primeroots" className="h-8 w-auto" />
            </a>
            <p className="mt-5 text-white/70 text-sm sm:text-base leading-relaxed max-w-xs">{t.footer.tagline}</p>
            <div className="mt-6 flex items-center gap-3">
              <a href="https://www.facebook.com/profile.php?id=61562840621824" target="_blank" rel="noopener noreferrer" aria-label="Facebook" className="w-10 h-10 rounded-full bg-white/10 hover:bg-brand-500 flex items-center justify-center transition-colors">
                <FacebookIcon className="w-4 h-4" />
              </a>
              <a href="https://www.instagram.com/primeroots_eg/" target="_blank" rel="noopener noreferrer" aria-label="Instagram" className="w-10 h-10 rounded-full bg-white/10 hover:bg-brand-500 flex items-center justify-center transition-colors">
                <InstagramIcon className="w-4 h-4" />
              </a>
              <a href="https://wa.me/201113315309" target="_blank" rel="noopener noreferrer" aria-label="WhatsApp" className="w-10 h-10 rounded-full bg-white/10 hover:bg-brand-500 flex items-center justify-center transition-colors">
                <WhatsappIcon className="w-4 h-4" />
              </a>
            </div>
          </div>
          <div>
            <h4 className="font-display font-bold text-base sm:text-lg mb-4">{t.footer.quick}</h4>
            <ul className="space-y-2.5">
              <li><a href="#home" className="text-white/70 hover:text-brand-300 transition-colors text-sm sm:text-base">{t.nav.home}</a></li>
              <li><a href="#products" className="text-white/70 hover:text-brand-300 transition-colors text-sm sm:text-base">{t.nav.shop}</a></li>
              <li><a href="#about" className="text-white/70 hover:text-brand-300 transition-colors text-sm sm:text-base">{t.nav.about}</a></li>
              <li><a href="#contact" className="text-white/70 hover:text-brand-300 transition-colors text-sm sm:text-base">{t.nav.contact}</a></li>
            </ul>
          </div>
          <div>
            <h4 className="font-display font-bold text-base sm:text-lg mb-4">{t.footer.site}</h4>
            <ul className="space-y-2.5">
              <li><a href="#" className="text-white/70 hover:text-brand-300 transition-colors text-sm sm:text-base">{t.footer.privacy}</a></li>
              <li><a href="#" className="text-white/70 hover:text-brand-300 transition-colors text-sm sm:text-base">{t.footer.terms}</a></li>
              <li><a href="#" className="text-white/70 hover:text-brand-300 transition-colors text-sm sm:text-base">{t.footer.shipping}</a></li>
            </ul>
          </div>
        </div>
        <div className="mt-12 pt-8 border-t border-white/10 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-sm text-white/60 text-center sm:text-start">© 2026 Primeroots. {t.footer.rights}</p>
          <button onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })} className="inline-flex items-center gap-1.5 text-sm text-white/60 hover:text-brand-300 transition-colors">
            <ArrowUp className="w-4 h-4" />
            {t.footer.back}
          </button>
        </div>
      </div>
    </footer>
  );
}