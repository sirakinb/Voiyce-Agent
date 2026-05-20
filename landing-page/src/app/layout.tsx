import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://voiyce.us"),
  title: {
    default: "Stop re-explaining your work to AI.",
    template: "%s — Voiyce",
  },
  description:
    "Voiyce is the agent context layer for Claude Code, Codex, Hermes Agent, OpenClaw, Cursor, and your workspace.",
  openGraph: {
    title: "Stop re-explaining your work to AI.",
    description:
      "Voiyce captures what you are doing and turns it into reusable agent context for the tools you work with.",
    url: "https://voiyce.us",
    siteName: "Voiyce",
    images: [
      {
        url: "/og-header.png",
        width: 1200,
        height: 630,
        alt: "Voiyce - Stop re-explaining your work to AI.",
      },
    ],
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Stop re-explaining your work to AI.",
    description:
      "The agent context layer for Claude Code, Codex, Hermes Agent, OpenClaw, Cursor, and your workspace.",
    images: ["/og-header.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <a href="#main-content" className="skip-link">
          Skip to content
        </a>
        <main id="main-content" className="min-h-full flex-1">
          {children}
        </main>
      </body>
    </html>
  );
}
