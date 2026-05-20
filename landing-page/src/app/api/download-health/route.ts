import { NextResponse } from "next/server";

import { downloadUrl } from "@/lib/voiyce-config";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const DOWNLOAD_CHECK_TIMEOUT_MS = 5000;

export async function GET() {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DOWNLOAD_CHECK_TIMEOUT_MS);

  try {
    const response = await fetch(downloadUrl, {
      method: "HEAD",
      cache: "no-store",
      signal: controller.signal,
    });

    if (!response.ok) {
      return NextResponse.json(
        { ok: false, status: response.status, downloadUrl },
        { status: 503 },
      );
    }

    return NextResponse.json({
      ok: true,
      status: response.status,
      downloadUrl,
    });
  } catch {
    return NextResponse.json(
      { ok: false, status: "unreachable", downloadUrl },
      { status: 503 },
    );
  } finally {
    clearTimeout(timeout);
  }
}
