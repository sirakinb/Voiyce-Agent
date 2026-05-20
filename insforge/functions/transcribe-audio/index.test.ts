import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts"
import handler, { selectTranscriptionModel } from "./index.ts"

function clearTranscriptionEnv() {
  for (const name of [
    "API_KEY",
    "INSFORGE_BASE_URL",
    "OPENAI_API_KEY",
    "OPENAI_TRANSCRIPTION_MODEL",
    "VOIYCE_ALLOW_CLIENT_TRANSCRIPTION_MODEL",
    "VOIYCE_DISABLE_ALL_AI",
    "VOIYCE_DISABLE_TRANSCRIPTION",
    "VOIYCE_ENFORCE_AGENT_USAGE_CAPS",
    "VOIYCE_TRANSCRIPTION_MAX_AUDIO_BYTES",
    "OPENAI_TRANSCRIPTION_COST_CENTS_PER_MINUTE",
  ]) {
    Deno.env.delete(name)
  }
}

Deno.test("transcription model ignores client override by default", () => {
  Deno.env.set("OPENAI_TRANSCRIPTION_MODEL", "whisper-1")

  try {
    assertEquals(selectTranscriptionModel("client-requested-model"), "whisper-1")
  } finally {
    Deno.env.delete("OPENAI_TRANSCRIPTION_MODEL")
  }
})

Deno.test("transcription model accepts client override only when explicitly allowed", () => {
  Deno.env.set("OPENAI_TRANSCRIPTION_MODEL", "whisper-1")
  Deno.env.set("VOIYCE_ALLOW_CLIENT_TRANSCRIPTION_MODEL", "true")

  try {
    assertEquals(selectTranscriptionModel("client-requested-model"), "client-requested-model")
  } finally {
    Deno.env.delete("OPENAI_TRANSCRIPTION_MODEL")
    Deno.env.delete("VOIYCE_ALLOW_CLIENT_TRANSCRIPTION_MODEL")
  }
})

Deno.test("transcription kill switch returns a disabled response before env lookup", async () => {
  clearTranscriptionEnv()
  Deno.env.set("VOIYCE_DISABLE_TRANSCRIPTION", "true")

  try {
    const response = await handler(new Request("https://functions.test/transcribe-audio", {
      method: "POST",
    }))
    const body = await response.json()

    assertEquals(response.status, 503)
    assertEquals(body.code, "capability_disabled")
    assertStringIncludes(body.displayMessage, "Transcription")
  } finally {
    clearTranscriptionEnv()
  }
})

Deno.test("global AI kill switch disables transcription", async () => {
  clearTranscriptionEnv()
  Deno.env.set("VOIYCE_DISABLE_ALL_AI", "1")

  try {
    const response = await handler(new Request("https://functions.test/transcribe-audio", {
      method: "POST",
    }))
    const body = await response.json()

    assertEquals(response.status, 503)
    assertEquals(body.code, "capability_disabled")
  } finally {
    clearTranscriptionEnv()
  }
})

Deno.test("transcription handles CORS preflight and unsupported methods before env lookup", async () => {
  clearTranscriptionEnv()

  const optionsResponse = await handler(new Request("https://functions.test/transcribe-audio", {
    method: "OPTIONS",
  }))
  assertEquals(optionsResponse.status, 204)
  assertStringIncludes(optionsResponse.headers.get("Access-Control-Allow-Methods") ?? "", "POST")

  const getResponse = await handler(new Request("https://functions.test/transcribe-audio", {
    method: "GET",
  }))
  const body = await getResponse.json()
  assertEquals(getResponse.status, 405)
  assertEquals(body.error, "Method not allowed")
})

Deno.test("transcription enforces audio size before billing profile or OpenAI calls", async () => {
  clearTranscriptionEnv()
  Deno.env.set("API_KEY", "test-api-key")
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")
  Deno.env.set("VOIYCE_TRANSCRIPTION_MAX_AUDIO_BYTES", "1")

  const originalFetch = globalThis.fetch
  globalThis.fetch = async () =>
    new Response(JSON.stringify({ user: { id: "user_123" } }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })

  try {
    const response = await handler(new Request("https://functions.test/transcribe-audio", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        audioBase64: btoa("too large"),
        fileName: "recording.wav",
        mimeType: "audio/wav",
        model: "client-requested-model",
      }),
    }))
    const body = await response.json()

    assertEquals(response.status, 413)
    assertStringIncludes(body.error, "Audio payload exceeds")
  } finally {
    globalThis.fetch = originalFetch
    clearTranscriptionEnv()
  }
})

Deno.test("transcription auth provider failures do not call OpenAI or leak auth payloads", async () => {
  clearTranscriptionEnv()
  Deno.env.set("API_KEY", "test-api-key")
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")

  const calls: string[] = []
  const originalFetch = globalThis.fetch
  globalThis.fetch = async (input) => {
    const url = String(input)
    if (url.includes("/api/auth/sessions/current")) {
      calls.push("auth")
      return new Response(JSON.stringify({ error: { message: "auth provider failed Authorization: Bearer leaked-token" } }), {
        status: 503,
        headers: { "Content-Type": "application/json" },
      })
    }

    calls.push("openai")
    return new Response(JSON.stringify({ text: "should not run" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/transcribe-audio", {
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
    const text = await response.text()
    const body = JSON.parse(text)

    assertEquals(response.status, 500)
    assertEquals(body.error, "The request failed. Please try again.")
    assertEquals(calls, ["auth"])
    assertEquals(text.includes("Bearer"), false)
    assertEquals(text.includes("leaked-token"), false)
  } finally {
    globalThis.fetch = originalFetch
    clearTranscriptionEnv()
  }
})

Deno.test("transcription billing profile failures do not call OpenAI or leak database payloads", async () => {
  clearTranscriptionEnv()
  Deno.env.set("API_KEY", "test-api-key")
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")

  const calls: string[] = []
  const originalFetch = globalThis.fetch
  globalThis.fetch = async (input) => {
    const url = String(input)
    if (url.includes("/api/auth/sessions/current")) {
      calls.push("auth")
      return new Response(JSON.stringify({ user: { id: "user_123" } }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }
    if (url.includes("/api/database/records/billing_profiles")) {
      calls.push("profile")
      return new Response(JSON.stringify({ error: { message: "database failed Authorization: Bearer leaked-token" } }), {
        status: 503,
        headers: { "Content-Type": "application/json" },
      })
    }

    calls.push("openai")
    return new Response(JSON.stringify({ text: "should not run" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/transcribe-audio", {
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
    const text = await response.text()
    const body = JSON.parse(text)

    assertEquals(response.status, 500)
    assertEquals(body.error, "The request failed. Please try again.")
    assertEquals(calls, ["auth", "profile"])
    assertEquals(text.includes("Bearer"), false)
    assertEquals(text.includes("leaked-token"), false)
  } finally {
    globalThis.fetch = originalFetch
    clearTranscriptionEnv()
  }
})

Deno.test("transcription usage limits return clear account-limit responses before OpenAI", async () => {
  clearTranscriptionEnv()
  Deno.env.set("API_KEY", "test-api-key")
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")
  Deno.env.set("VOIYCE_ENFORCE_AGENT_USAGE_CAPS", "true")

  const calls: string[] = []
  const originalFetch = globalThis.fetch
  globalThis.fetch = async (input) => {
    const url = String(input)
    if (url.includes("/api/auth/sessions/current")) {
      calls.push("auth")
      return new Response(JSON.stringify({ user: { id: "user_123" } }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }
    if (url.includes("/api/database/records/billing_profiles")) {
      calls.push("profile")
      return new Response(JSON.stringify([{ user_id: "user_123", subscription_status: "inactive" }]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }
    if (url.includes("/api/database/rpc/reserve_agent_usage_cost")) {
      calls.push("reserve")
      return new Response(JSON.stringify({ error: { message: "Monthly transcription usage cap reached for default tier" } }), {
        status: 429,
        headers: { "Content-Type": "application/json" },
      })
    }

    calls.push("openai")
    return new Response(JSON.stringify({ text: "should not run" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/transcribe-audio", {
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
    const body = await response.json()

    assertEquals(response.status, 402)
    assertEquals(body.code, "usage_limit_reached")
    assertEquals(body.error, "Monthly transcription usage cap reached for default tier")
    assertEquals(calls, ["auth", "profile", "reserve"])
  } finally {
    globalThis.fetch = originalFetch
    clearTranscriptionEnv()
  }
})

Deno.test("transcription upstream errors do not expose secrets to the client", async () => {
  clearTranscriptionEnv()
  Deno.env.set("API_KEY", "test-api-key")
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")
  const leakedSecret = `${["OPENAI_API", "KEY"].join("_")}=${["sk", "proj"].join("-")}-not-real-secret-1234567890`

  const originalFetch = globalThis.fetch
  globalThis.fetch = async (input) => {
    const url = String(input)
    if (url.includes("/api/auth/sessions/current")) {
      return new Response(JSON.stringify({ user: { id: "user_123" } }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }
    if (url.includes("/api/database/records/billing_profiles")) {
      return new Response(JSON.stringify([]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }

    return new Response(JSON.stringify({ error: { message: `upstream leaked ${leakedSecret}` } }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/transcribe-audio", {
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
    const text = await response.text()
    const body = JSON.parse(text)

    assertEquals(response.status, 502)
    assertEquals(body.error, "The AI service is temporarily unavailable. Please try again.")
    assertEquals(text.includes("not-real-secret"), false)
    assertEquals(text.includes("OPENAI_API_KEY"), false)
  } finally {
    globalThis.fetch = originalFetch
    clearTranscriptionEnv()
  }
})

Deno.test("transcription preserves OpenAI auth and rate-limit status without leaking upstream payload", async () => {
  for (const upstreamStatus of [401, 429]) {
    clearTranscriptionEnv()
    Deno.env.set("API_KEY", "test-api-key")
    Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
    Deno.env.set("OPENAI_API_KEY", "test-openai-key")

    const originalFetch = globalThis.fetch
    globalThis.fetch = async (input) => {
      const url = String(input)
      if (url.includes("/api/auth/sessions/current")) {
        return new Response(JSON.stringify({ user: { id: "user_123" } }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }
      if (url.includes("/api/database/records/billing_profiles")) {
        return new Response(JSON.stringify([]), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }

      return new Response(JSON.stringify({ error: { message: `upstream ${upstreamStatus} quota OPENAI_API_KEY=redacted-test` } }), {
        status: upstreamStatus,
        headers: { "Content-Type": "application/json" },
      })
    }

    try {
      const response = await handler(new Request("https://functions.test/transcribe-audio", {
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
      const text = await response.text()
      const body = JSON.parse(text)

      assertEquals(response.status, upstreamStatus)
      assertEquals(body.error, "The AI service is temporarily unavailable. Please try again.")
      assertEquals(body.upstreamStatus, upstreamStatus)
      assertEquals(text.includes("OPENAI_API_KEY"), false)
      assertEquals(text.includes("quota"), false)
    } finally {
      globalThis.fetch = originalFetch
      clearTranscriptionEnv()
    }
  }
})

Deno.test("transcription reserves and finalizes usage caps when enabled", async () => {
  clearTranscriptionEnv()
  Deno.env.set("API_KEY", "test-api-key")
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")
  Deno.env.set("VOIYCE_ENFORCE_AGENT_USAGE_CAPS", "true")
  Deno.env.set("OPENAI_TRANSCRIPTION_COST_CENTS_PER_MINUTE", "1.2")

  const calls: Array<{ kind: string; body?: Record<string, unknown> }> = []
  const originalFetch = globalThis.fetch
  globalThis.fetch = async (input, init) => {
    const url = String(input)
    if (url.includes("/api/auth/sessions/current")) {
      calls.push({ kind: "auth" })
      return new Response(JSON.stringify({ user: { id: "user_123" } }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }

    if (url.includes("/api/database/records/billing_profiles")) {
      calls.push({ kind: "profile" })
      return new Response(JSON.stringify([{ user_id: "user_123", subscription_status: "inactive" }]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }

    if (url.includes("/api/database/rpc/reserve_agent_usage_cost")) {
      const body = JSON.parse(String((init as { body?: BodyInit | null } | undefined)?.body ?? "{}")) as Record<string, unknown>
      calls.push({ kind: "reserve", body })
      return new Response(JSON.stringify([{ usage_id: "usage_123" }]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }

    if (url.includes("/api/database/rpc/finalize_agent_usage_cost")) {
      const body = JSON.parse(String((init as { body?: BodyInit | null } | undefined)?.body ?? "{}")) as Record<string, unknown>
      calls.push({ kind: "finalize", body })
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }

    calls.push({ kind: "openai" })
    return new Response(JSON.stringify({ text: "hello world" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/transcribe-audio", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        audioBase64: btoa("audio"),
        fileName: "recording.wav",
        mimeType: "audio/wav",
        durationSeconds: 30,
      }),
    }))
    const body = await response.json()

    assertEquals(response.status, 200)
    assertEquals(body.text, "hello world")
    assertEquals(calls.map((call) => call.kind), ["auth", "profile", "reserve", "openai", "finalize"])
    assertEquals(calls[2].body, {
      p_user_id: "user_123",
      p_capability: "transcription",
      p_estimated_cost_usd: 0.006,
      p_usage_units: {
        request_count: 1,
        audio_seconds: 30,
        audio_bytes: 5,
      },
    })
    assertEquals(calls[4].body, {
      p_usage_id: "usage_123",
      p_succeeded: true,
    })
  } finally {
    globalThis.fetch = originalFetch
    clearTranscriptionEnv()
  }
})
