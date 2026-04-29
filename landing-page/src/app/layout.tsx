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
  metadataBase: new URL("https://voiyce-mac-app.vercel.app"),
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
    url: "https://voiyce-mac-app.vercel.app",
    siteName: "Voiyce",
    images: [
      {
        url: "/opengraph-image",
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
    images: ["/opengraph-image"],
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
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
