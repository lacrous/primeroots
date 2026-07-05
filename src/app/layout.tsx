import type { Metadata } from "next";
import { Montserrat, Playfair_Display, Cairo } from "next/font/google";
import { I18nProvider } from "@/lib/i18n-context";
import "./globals.css";

const montserrat = Montserrat({
  variable: "--font-montserrat",
  subsets: ["latin"],
  display: "swap",
});

const playfair = Playfair_Display({
  variable: "--font-playfair",
  subsets: ["latin"],
  display: "swap",
});

const cairo = Cairo({
  variable: "--font-arabic",
  subsets: ["arabic"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Primeroots — Premium Tropical Jam from Egypt",
  description: "Premium tropical jams made from real fruit. No artificial colors, no preservatives. Lychee, Passion Fruit, Dragon Fruit & Strawberry. Cairo, Egypt.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${montserrat.variable} ${playfair.variable} ${cairo.variable} h-full antialiased`}>
      <body className="min-h-screen flex flex-col bg-white">
        <I18nProvider>{children}</I18nProvider>
      </body>
    </html>
  );
}