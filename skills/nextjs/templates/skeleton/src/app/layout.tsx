import type { Metadata, Viewport } from "next";
import Link from "next/link";

import { env } from "@/env";

import "./globals.css";

// Metadata is static here; a page that needs its own title exports
// `metadata` or `generateMetadata`. Fonts: prefer `next/font/local` with a
// committed file so builds never fetch; the system stack is the default.
export const metadata: Metadata = {
  title: { default: env.NEXT_PUBLIC_APP_NAME, template: `%s | ${env.NEXT_PUBLIC_APP_NAME}` },
  description: `${env.NEXT_PUBLIC_APP_NAME} web app`,
  icons: { icon: "/favicon.svg" },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  colorScheme: "light dark",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-svh bg-background font-sans text-foreground">
        <header className="border-b">
          <nav aria-label="Main" className="mx-auto flex max-w-5xl items-center gap-4 px-4 py-3">
            <Link href="/" className="font-semibold">
              {env.NEXT_PUBLIC_APP_NAME}
            </Link>
          </nav>
        </header>
        <main className="mx-auto max-w-5xl px-4 py-8">{children}</main>
      </body>
    </html>
  );
}
