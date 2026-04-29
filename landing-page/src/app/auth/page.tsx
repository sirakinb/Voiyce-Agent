import type { Metadata } from "next";
import { Suspense } from "react";

import AuthPageClient from "@/components/AuthPageClient";
import AuthRouteSkeleton from "@/components/AuthRouteSkeleton";

export const metadata: Metadata = {
  title: "Create Account",
  description:
    "Create your Voiyce account, then download the Mac app and finish setup inside the app.",
};

export default function AuthPage() {
  return (
    <Suspense fallback={<AuthRouteSkeleton />}>
      <AuthPageClient />
    </Suspense>
  );
}
