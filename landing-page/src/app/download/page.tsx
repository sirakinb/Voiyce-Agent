import type { Metadata } from "next";
import { Suspense } from "react";

import DownloadPageClient from "@/components/DownloadPageClient";

export const metadata: Metadata = {
  title: "Download For Mac",
  description:
    "Download the Voiyce Mac app, install it, then sign in inside the app to finish onboarding.",
};

export default function DownloadPage() {
  return (
    <Suspense fallback={null}>
      <DownloadPageClient />
    </Suspense>
  );
}
