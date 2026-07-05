"use client";

import { useState } from "react";
import { Phone, Mail, MapPin, Send, MessageCircle, Check } from "lucide-react";
import { useI18n } from "@/lib/i18n-context";

export function Contact() {
  const { t, locale } = useI18n();
  const isRtl = locale === "ar";
  const [status, setStatus] = useState<"idle" | "success">("idle");

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const data = new FormData(e.currentTarget);
    const subject = encodeURIComponent(String(data.get("subject") || ""));
    const body = encodeURIComponent(`${data.get("name")} <${data.get("email")}>\n\n${data.get("message") || ""}`);
    window.location.href = `mailto:info@primeroots-eg.com?subject=${subject}&body=${body}`;
    setStatus("success");
    setTimeout(() => setStatus("idle"), 4000);
  };

  const items = [
    { icon: Phone, label: t.contact.phone, value: "0111 331 5309", href: "tel:+201113315309" },
    { icon: Phone, label: t.contact.phone, value: "0100 543 7940", href: "tel:+201005437940" },
    { icon: Mail, label: t.contact.email, value: "info@primeroots-eg.com", href: "mailto:info@primeroots-eg.com" },
    { icon: MapPin, label: t.contact.location, value: t.contact.cairo, href: null },
  ];

  return (
    <section id="contact" className="py-16 sm:py-20 lg:py-28 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-10 lg:gap-16">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-brand-100 text-brand-700 text-xs sm:text-sm font-semibold mb-4">
              <span className="w-1.5 h-1.5 rounded-full bg-brand-500" />
              {t.contact.title}
            </div>
            <h2 className="font-display text-3xl sm:text-4xl lg:text-5xl font-bold text-forest-500 leading-tight">{t.contact.title}</h2>
            <p className="mt-4 text-base sm:text-lg text-gray-600 max-w-md">{t.contact.sub}</p>

            <div className="mt-8 space-y-4">
              {items.map((item, i) => {
                const Icon = item.icon;
                const Wrapper = item.href ? "a" : "div";
                return (
                  <Wrapper
                    key={i}
                    href={item.href ?? undefined}
                    className="group flex items-center gap-4 p-4 rounded-2xl bg-cream hover:bg-brand-50 border border-forest-100 hover:border-brand-200 transition-all"
                  >
                    <div className="w-11 h-11 rounded-full bg-forest-500 group-hover:bg-brand-500 flex items-center justify-center text-white transition-colors flex-shrink-0">
                      <Icon className="w-5 h-5" />
                    </div>
                    <div className="min-w-0">
                      <div className="text-xs text-gray-500 uppercase tracking-wider font-semibold">{item.label}</div>
                      <div className="text-forest-500 font-semibold text-sm sm:text-base truncate" dir={item.label === t.contact.email ? "ltr" : undefined}>{item.value}</div>
                    </div>
                  </Wrapper>
                );
              })}
            </div>

            <a
              href="https://wa.me/201113315309"
              target="_blank"
              rel="noopener noreferrer"
              className="mt-6 inline-flex items-center gap-2 px-6 py-3.5 bg-[#25D366] hover:bg-[#1ebe5d] text-white font-bold rounded-full transition-colors shadow-lg shadow-[#25D366]/20"
            >
              <MessageCircle className="w-5 h-5" />
              {t.contact.whatsapp}
            </a>
          </div>

          <div className="bg-cream rounded-3xl p-6 sm:p-8 lg:p-10 border border-forest-100">
            <form onSubmit={handleSubmit} className="space-y-5">
              <div>
                <label className="block text-sm font-semibold text-forest-500 mb-1.5">{t.contact.name}</label>
                <input name="name" type="text" required className="w-full px-4 py-3 rounded-xl bg-white border border-forest-100 focus:border-brand-500 focus:ring-2 focus:ring-brand-200 outline-none transition-colors" />
              </div>
              <div>
                <label className="block text-sm font-semibold text-forest-500 mb-1.5">{t.contact.yourEmail}</label>
                <input name="email" type="email" required className="w-full px-4 py-3 rounded-xl bg-white border border-forest-100 focus:border-brand-500 focus:ring-2 focus:ring-brand-200 outline-none transition-colors" dir="ltr" />
              </div>
              <div>
                <label className="block text-sm font-semibold text-forest-500 mb-1.5">{t.contact.subject}</label>
                <input name="subject" type="text" required className="w-full px-4 py-3 rounded-xl bg-white border border-forest-100 focus:border-brand-500 focus:ring-2 focus:ring-brand-200 outline-none transition-colors" />
              </div>
              <div>
                <label className="block text-sm font-semibold text-forest-500 mb-1.5">{t.contact.message}</label>
                <textarea name="message" rows={4} className="w-full px-4 py-3 rounded-xl bg-white border border-forest-100 focus:border-brand-500 focus:ring-2 focus:ring-brand-200 outline-none transition-colors resize-none" />
              </div>
              <button type="submit" className="w-full inline-flex items-center justify-center gap-2 px-6 py-4 bg-forest-500 hover:bg-forest-600 text-white font-bold rounded-full transition-colors shadow-lg shadow-forest-500/20">
                {status === "success" ? <><Check className="w-5 h-5" />OK</> : <><Send className={`w-4 h-4 ${isRtl ? "rotate-180" : ""}`} />{t.contact.submit}</>}
              </button>
            </form>
          </div>
        </div>
      </div>
    </section>
  );
}