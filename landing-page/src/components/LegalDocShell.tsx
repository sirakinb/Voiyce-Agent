import type { ReactNode } from "react";
import Link from "next/link";

export function LegalDocShell({
  title,
  lastUpdated,
  children,
}: {
  title: string;
  lastUpdated: string;
  children: ReactNode;
}) {
  return (
    <div className="min-h-screen bg-black text-[#EDEDED]">
      <article className="mx-auto max-w-3xl px-6 py-16 md:py-24">
        <Link
          href="/"
          className="mb-10 inline-block text-sm font-medium text-purple-400 transition-colors hover:text-purple-300"
        >
          ← Back to home
        </Link>
        <h1 className="mb-2 text-4xl font-bold tracking-tight text-white md:text-5xl">
          {title}
        </h1>
        <p className="mb-12 text-sm text-[#666666]">Last updated: {lastUpdated}</p>
        <div className="space-y-8 text-[15px] leading-relaxed text-[#a3a3a3] [&_h2]:mt-12 [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:text-white [&_h2]:first:mt-0 [&_h3]:mt-8 [&_h3]:text-base [&_h3]:font-semibold [&_h3]:text-white [&_ul]:list-disc [&_ul]:space-y-2 [&_ul]:pl-5 [&_strong]:font-semibold [&_strong]:text-[#e5e5e5]">
          {children}
        </div>
      </article>
    </div>
  );
}
