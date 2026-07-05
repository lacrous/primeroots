"use client";

import { useEffect, useState } from "react";
import { Menu, X, ShoppingBag, Languages } from "lucide-react";
import { useI18n } from "@/lib/i18n-context";
import { LOGO_DARK } from "@/lib/utils";

export function Header() {
  const { t, locale, setLocale } = useI18n();
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const navLinks = [
    { href: "#home", label: t.nav.home },
    { href: "#products", label: t.nav.shop },
    { href: "#about", label: t.nav.about },
    { href: "#contact", label: t.nav.contact },
  ];

  return (
    <header
      className={`sticky top-0 z-40 w-full transition-all duration-300 ${
        scrolled
          ? "bg-white/95 backdrop-blur-md shadow-sm border-b border-forest-100/50"
          : "bg-white border-b border-transparent"
      }`}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16 sm:h-20">
          <a href="#home" aria-label="Primeroots">
            <img src={LOGO_DARK} alt="Primeroots" className="h-7 sm:h-8 w-auto" />
          </a>

          <nav className="hidden md:flex items-center gap-1">
            {navLinks.map((link) => (
              <a key={link.href} href={link.href} className="px-4 py-2 text-sm font-semibold text-forest-500 hover:text-brand-600 transition-colors">
                {link.label}
              </a>
            ))}
          </nav>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setLocale(locale === "en" ? "ar" : "en")}
              aria-label="Language"
              className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-full text-sm font-semibold text-forest-500 hover:bg-forest-50 transition-colors"
            >
              <Languages className="w-4 h-4" />
              <span>{locale === "ar" ? "EN" : "ع"}</span>
            </button>
            <a
              href="#products"
              className="hidden sm:inline-flex items-center gap-2 px-4 py-2 bg-forest-500 hover:bg-forest-600 text-white text-sm font-semibold rounded-full transition-colors"
            >
              <ShoppingBag className="w-4 h-4" />
              {t.nav.shopNow}
            </a>
            <button
              onClick={() => setMobileOpen((v) => !v)}
              className="md:hidden p-2 text-forest-500"
              aria-label="Menu"
            >
              {mobileOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>
          </div>
        </div>
      </div>

      {mobileOpen && (
        <div className="md:hidden border-t border-forest-100 bg-white">
          <nav className="flex flex-col px-4 py-2">
            {navLinks.map((link) => (
              <a
                key={link.href}
                href={link.href}
                onClick={() => setMobileOpen(false)}
                className="py-3 text-base font-semibold text-forest-500 border-b border-forest-50 last:border-0"
              >
                {link.label}
              </a>
            ))}
          </nav>
        </div>
      )}
    </header>
  );
}