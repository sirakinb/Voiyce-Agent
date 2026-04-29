/** Shared skeleton for /auth route (loading.tsx + Suspense while searchParams resolve). */
export default function AuthRouteSkeleton() {
  return (
    <div className="min-h-screen bg-[#050505] text-white">
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute -top-40 left-1/2 h-[36rem] w-[36rem] -translate-x-1/2 rounded-full bg-purple-500/10 blur-[140px]" />
      </div>
      <div className="relative flex min-h-screen items-center justify-center px-4 py-4 md:px-6 md:py-6">
        <div className="w-full max-w-[34rem] animate-pulse space-y-6">
          <div className="mx-auto h-40 w-48 rounded-lg bg-white/[0.06]" />
          <div className="rounded-[2rem] border border-white/10 bg-[#111117]/95 p-8 md:p-10">
            <div className="h-6 w-32 rounded bg-white/[0.08]" />
            <div className="mt-4 h-10 w-3/4 max-w-sm rounded bg-white/[0.06]" />
            <div className="mt-8 h-14 w-full rounded-2xl bg-white/[0.06]" />
            <div className="mt-6 h-14 w-full rounded-2xl bg-white/[0.06]" />
          </div>
        </div>
      </div>
    </div>
  );
}
