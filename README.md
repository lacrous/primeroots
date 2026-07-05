# Primeroots — Next.js Project

A modern bilingual (Arabic + English) marketing site for **Primeroots**, an Egyptian tropical fruit jam brand. Built with **Next.js 16 + TypeScript + Tailwind CSS v4**.

**Built for Vercel** — just push to GitHub and import, or drag-and-drop the project folder.

---

## Stack

- **Next.js 16** (App Router) + **TypeScript**
- **Tailwind CSS v4** with custom brand theme (gold + forest green + cream)
- **React 19**
- **lucide-react** icons
- Client-side i18n (no middleware, no routing — language toggle just swaps state)

No backend, no API routes, no database. Just a single page.

---

## Quick start

```bash
npm install      # install dependencies (one time)
npm run dev      # start dev server → http://localhost:3000
npm run build    # production build
npm start        # run production build locally
```

---

## Project structure

```
primeroots-full/
├── next.config.ts
├── package.json          ← Vercel reads this — has "next" dep ✅
├── tsconfig.json
├── postcss.config.mjs
├── public/
├── src/
│   ├── app/
│   │   ├── layout.tsx    ← root layout + fonts (Montserrat, Playfair, Cairo)
│   │   ├── page.tsx      ← single home page
│   │   └── globals.css   ← Tailwind + custom theme
│   ├── components/
│   │   ├── AnnouncementBar.tsx
│   │   ├── Header.tsx
│   │   ├── Hero.tsx
│   │   ├── FeaturedProduct.tsx
│   │   ├── ProductsGrid.tsx
│   │   ├── About.tsx
│   │   ├── FAQ.tsx
│   │   ├── Testimonials.tsx
│   │   ├── Contact.tsx
│   │   └── Footer.tsx
│   └── lib/
│       ├── utils.ts          ← product data + image URLs
│       ├── i18n.ts           ← all English + Arabic text
│       └── i18n-context.tsx  ← client-side language context
└── README.md
```

---

## Deploy to Vercel

### Option A: GitHub (recommended)
1. Push this folder to a GitHub repo
2. Go to [vercel.com/new](https://vercel.com/new)
3. Import the repo → Vercel auto-detects Next.js → click Deploy

### Option B: Drag-and-drop
1. Run `npm run build` locally
2. Go to [vercel.com/new](https://vercel.com/new) → "Import Project" → drag this folder
3. Vercel will see `next` in `package.json` and configure automatically

### Option C: Vercel CLI
```bash
npm i -g vercel
vercel        # follow prompts
```

---

## Editing content

Open `src/lib/i18n.ts` — every string on the site lives in either the `en` or `ar` object. Change text in either place and both languages stay in sync.

To add a new product, edit `src/lib/utils.ts` — add an entry to the `products` array. Then add the name in both languages in `src/lib/i18n.ts` under `productNames`.

---

## Brand contact

- WhatsApp: +20 111 331 5309
- Email: info@primeroots-eg.com
- Cairo, Egypt

---

Built for Nurovia.