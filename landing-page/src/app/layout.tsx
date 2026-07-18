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
    default: "Write at the speed of thought.",
    template: "%s — Voiyce",
  },
  description:
    "Download Voiyce for macOS and turn natural speech into polished text in any app.",
  openGraph: {
    title: "Write at the speed of thought.",
    description:
      "Download Voiyce for macOS and turn natural speech into polished text in any app.",
    url: "https://voiyce.us",
    siteName: "Voiyce",
    images: [
      {
        url: "/og-header.png",
        width: 1200,
        height: 630,
        alt: "Voiyce - Write at the speed of thought. Download for macOS.",
      },
    ],
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Write at the speed of thought.",
    description:
      "Download Voiyce for macOS and turn natural speech into polished text in any app.",
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
