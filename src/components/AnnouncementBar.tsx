"use client";

import { Truck } from "lucide-react";
import { useI18n } from "@/lib/i18n-context";

export function AnnouncementBar() {
  const { t } = useI18n();
  return (
    <div className="bg-[#1f3d2b] text-white text-xs sm:text-sm py-2 px-4">
      <div className="flex items-center justify-center gap-2 max-w-7xl mx-auto">
        <Truck className="w-3.5 h-3.5 sm:w-4 sm:h-4 flex-shrink-0" />
        <span className="font-medium tracking-wide">{t.announce}</span>
      </div>
    </div>
  );
}