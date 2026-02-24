import { RootProvider } from "fumadocs-ui/provider/next";
import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./global.css";
import { Inter } from "next/font/google";

const inter = Inter({
  subsets: ["latin"],
});

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
};

export const metadata: Metadata = {
  title: {
    default: "Hobenakicoffee Playground",
    template: "%s | Hobenakicoffee Playground",
  },
  description: "Playground for Hobenakicoffee libraries and components",
  keywords: ["hobenakicoffee", "playground", "documentation", "libraries"],
  authors: [{ name: "Hobenakicoffee" }],
  openGraph: {
    title: "Hobenakicoffee Playground",
    description: "Playground for Hobenakicoffee libraries and components",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Hobenakicoffee Playground",
    description: "Playground for Hobenakicoffee libraries and components",
  },
};

export default function Layout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={inter.className} suppressHydrationWarning>
      <body className="flex flex-col min-h-screen">
        <RootProvider>{children}</RootProvider>
      </body>
    </html>
  );
}
