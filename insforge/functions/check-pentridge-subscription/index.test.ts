import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts"
import handler from "./index.ts"
import transcribeAudio from "../transcribe-audio/index.ts"

function clearPentridgeEnv() {
  Deno.env.delete("INSFORGE_BASE_URL")
  Deno.env.delete("API_KEY")
  Deno.env.delete("OPENAI_API_KEY")
}

Deno.test("entitled first-login user gets a billing profile before Pentridge entitlement is cached", async () => {
  clearPentridgeEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("API_KEY", "test-api-key")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")

  const calls: Array<{ kind: string; body?: unknown }> = []
  const originalFetch = globalThis.fetch
  globalThis.fetch = async (input, init) => {
    const url = String(input)
    if (url.includes("/api/auth/sessions/current")) {
      calls.push({ kind: "auth" })
      return new Response(JSON.stringify({
        user: { id: "user_123", email: "sirakinb@gmail.com" },
      }), { status: 200, headers: { "Content-Type": "application/json" } })
    }

    if (url.includes("/api/database/records/billing_profiles")) {
      const body = init?.body ? JSON.parse(String(init.body)) : undefined
      if (init?.method === "POST") {
        calls.push({ kind: "profile-insert", body })
        return new Response("[]", { status: 201, headers: { "Content-Type": "application/json" } })
      }
      if (init?.method === "PATCH") {
        calls.push({ kind: "profile-cache", body })
        return new Response(null, { status: 204 })
      }
      if (init?.method === "GET") {
        calls.push({ kind: "profile-read" })
        return new Response("[]", { status: 200, headers: { "Content-Type": "application/json" } })
      }
    }

    if (url.includes("/api/database/rpc/get_billing_status")) {
      calls.push({ kind: "billing-status" })
      return new Response(JSON.stringify([{
        needs_subscription: false,
        pentridge_subscription_active: true,
        pentridge_cap_reached: false,
      }]), { status: 200, headers: { "Content-Type": "application/json" } })
    }

    if (url.includes("/v1/audio/transcriptions")) {
      calls.push({ kind: "openai" })
      return new Response(JSON.stringify({ text: "entitled first-login transcript" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }

    throw new Error(`Unexpected request: ${url}`)
  }

  try {
    const response = await handler(new Request("https://functions.test/check-pentridge-subscription", {
      method: "POST",
      headers: { Authorization: "Bearer user-token" },
    }))

    assertEquals(response.status, 200)
    assertEquals(await response.json(), { has_subscription: true, tier: "pro" })
    assertEquals(calls.map(({ kind }) => kind), ["auth", "profile-insert", "profile-cache"])
    assertEquals(calls[1].body, [{ user_id: "user_123" }])
    const cached = calls[2].body as Record<string, unknown>
    assertEquals(cached.pentridge_subscription_active, true)
    assertEquals(cached.pentridge_tier, "pro")
    assertEquals(typeof cached.pentridge_checked_at, "string")

    const transcription = await transcribeAudio(new Request("https://functions.test/transcribe-audio", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        audioBase64: btoa("audio"),
        fileName: "recording.wav",
        mimeType: "audio/wav",
      }),
    }))

    assertEquals(transcription.status, 200)
    assertEquals(await transcription.json(), { text: "entitled first-login transcript" })
    assertEquals(calls.map(({ kind }) => kind), [
      "auth",
      "profile-insert",
      "profile-cache",
      "auth",
      "billing-status",
      "profile-read",
      "openai",
    ])
  } finally {
    globalThis.fetch = originalFetch
    clearPentridgeEnv()
  }
})
