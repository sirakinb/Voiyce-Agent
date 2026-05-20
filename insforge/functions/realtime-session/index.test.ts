import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts"
import handler, { buildRealtimeInstructions, buildRealtimeSession, selectRealtimeModel } from "./index.ts"

function clearRealtimeEnv() {
  for (const name of [
    "INSFORGE_BASE_URL",
    "OPENAI_API_KEY",
    "OPENAI_REALTIME_MODEL",
    "VOIYCE_ALLOW_CLIENT_REALTIME_MODEL",
    "VOIYCE_DISABLE_ALL_AI",
    "VOIYCE_DISABLE_REALTIME",
    "VOIYCE_ENFORCE_AGENT_USAGE_CAPS",
    "VOIYCE_REALTIME_MAX_SDP_CHARS",
    "VOIYCE_REALTIME_ESTIMATED_SESSION_COST_USD",
  ]) {
    Deno.env.delete(name)
  }
}

Deno.test("realtime model ignores client override by default", () => {
  Deno.env.set("OPENAI_REALTIME_MODEL", "gpt-realtime-2")

  try {
    assertEquals(selectRealtimeModel("client-requested-model"), "gpt-realtime-2")
  } finally {
    Deno.env.delete("OPENAI_REALTIME_MODEL")
  }
})

Deno.test("realtime model accepts client override only when explicitly allowed", () => {
  Deno.env.set("OPENAI_REALTIME_MODEL", "gpt-realtime-2")
  Deno.env.set("VOIYCE_ALLOW_CLIENT_REALTIME_MODEL", "true")

  try {
    assertEquals(selectRealtimeModel("client-requested-model"), "client-requested-model")
  } finally {
    Deno.env.delete("OPENAI_REALTIME_MODEL")
    Deno.env.delete("VOIYCE_ALLOW_CLIENT_REALTIME_MODEL")
  }
})

Deno.test("realtime instructions keep long tool waits conversational", () => {
  const talkInstructions = buildRealtimeInstructions("talk")

  assertStringIncludes(talkInstructions, "long-running tool action")
  assertStringIncludes(talkInstructions, "I am checking that now")
  assertStringIncludes(talkInstructions, "Give me a second, I am reading the screen")
  assertStringIncludes(talkInstructions, "do not immediately say you cannot do it")
  assertStringIncludes(talkInstructions, "retry one appropriate grounding tool")
})

Deno.test("realtime instructions preserve Talk and Act mode boundaries", () => {
  const talkInstructions = buildRealtimeInstructions("talk")
  const actInstructions = buildRealtimeInstructions("act")

  assertStringIncludes(talkInstructions, "The current user-facing mode is Talk")
  assertStringIncludes(talkInstructions, "Reserve act_with_computer for Act mode")
  assertStringIncludes(actInstructions, "The current user-facing mode is Act")
  assertStringIncludes(actInstructions, "search saved memory first")
  assertStringIncludes(actInstructions, "Narrate briefly when you are checking the screen or running an action")
})

Deno.test("realtime instructions require saved-memory grounding and hide technical source names", () => {
  const instructions = buildRealtimeInstructions("talk")

  assertStringIncludes(instructions, "Use saved memory tools before answering questions about previous sessions")
  assertStringIncludes(instructions, "cite the date or session in natural language")
  assertStringIncludes(instructions, "do not recite raw tool fields")
  assertStringIncludes(instructions, "Do not expose internal provider, runtime, tool, or source-label names")
  assertEquals(instructions.includes("VideoDB memory"), false)
  assertEquals(instructions.includes("OpenAI Computer Use"), false)
})

Deno.test("realtime instructions route screen and memory questions to the right context source", () => {
  const instructions = buildRealtimeInstructions("talk")

  assertStringIncludes(instructions, "Use it before answering or acting on screen-dependent requests")
  assertStringIncludes(instructions, "what I am looking at")
  assertStringIncludes(instructions, "Use active-session context for temporal questions")
  assertStringIncludes(instructions, "what happened earlier in the current agent session")
  assertStringIncludes(instructions, "Prefer current screen first, active-session context second, and saved memory third")
  assertStringIncludes(instructions, "If inspect_screen reports missing Screen Recording permission")
  assertStringIncludes(instructions, "offer request_screen_access")
})

Deno.test("realtime instructions do not hallucinate missing OAuth or permission access", () => {
  const instructions = buildRealtimeInstructions("talk")

  assertStringIncludes(instructions, "requires google_oauth")
  assertStringIncludes(instructions, "lacks Screen Recording/Microphone/Accessibility permission")
  assertStringIncludes(instructions, "state that exact user-facing blocker and next step")
  assertStringIncludes(instructions, "Do not infer account, inbox, calendar, screen, or app access")
})

Deno.test("realtime instructions route voice confirmation stop requests", () => {
  const instructions = buildRealtimeInstructions("act")

  assertStringIncludes(instructions, "needsConfirmation with a confirmation_id")
  assertStringIncludes(instructions, "decision approve")
  assertStringIncludes(instructions, "decision cancel")
  assertStringIncludes(instructions, "decision stop_session")
})

Deno.test("realtime session turn detection waits through natural pauses", () => {
  const session = buildRealtimeSession("gpt-realtime-2", "talk")

  assertEquals(session.audio.input.turn_detection, {
    type: "semantic_vad",
    eagerness: "low",
    create_response: true,
    interrupt_response: true,
  })
})

Deno.test("realtime kill switch returns a disabled response before env lookup", async () => {
  clearRealtimeEnv()
  Deno.env.set("VOIYCE_DISABLE_REALTIME", "true")

  try {
    const response = await handler(new Request("https://functions.test/realtime-session", {
      method: "POST",
    }))
    const body = await response.json()

    assertEquals(response.status, 503)
    assertEquals(body.code, "capability_disabled")
    assertStringIncludes(body.displayMessage, "Realtime voice")
  } finally {
    clearRealtimeEnv()
  }
})

Deno.test("global AI kill switch disables realtime", async () => {
  clearRealtimeEnv()
  Deno.env.set("VOIYCE_DISABLE_ALL_AI", "1")

  try {
    const response = await handler(new Request("https://functions.test/realtime-session", {
      method: "POST",
    }))
    const body = await response.json()

    assertEquals(response.status, 503)
    assertEquals(body.code, "capability_disabled")
  } finally {
    clearRealtimeEnv()
  }
})

Deno.test("realtime handles CORS preflight and unsupported methods before env lookup", async () => {
  clearRealtimeEnv()

  const optionsResponse = await handler(new Request("https://functions.test/realtime-session", {
    method: "OPTIONS",
  }))
  assertEquals(optionsResponse.status, 204)
  assertStringIncludes(optionsResponse.headers.get("Access-Control-Allow-Methods") ?? "", "POST")

  const getResponse = await handler(new Request("https://functions.test/realtime-session", {
    method: "GET",
  }))
  const body = await getResponse.json()
  assertEquals(getResponse.status, 405)
  assertEquals(body.error, "Method not allowed")
})

Deno.test("realtime enforces SDP size before calling OpenAI", async () => {
  clearRealtimeEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")
  Deno.env.set("VOIYCE_REALTIME_MAX_SDP_CHARS", "8")

  const originalFetch = globalThis.fetch
  globalThis.fetch = async () =>
    new Response(JSON.stringify({ user: { id: "user_123" } }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })

  try {
    const response = await handler(new Request("https://functions.test/realtime-session", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sdp: "0123456789", model: "client-requested-model" }),
    }))
    const body = await response.json()

    assertEquals(response.status, 413)
    assertStringIncludes(body.error, "SDP offer exceeds")
  } finally {
    globalThis.fetch = originalFetch
    clearRealtimeEnv()
  }
})

Deno.test("realtime auth provider failures do not call OpenAI or leak auth payloads", async () => {
  clearRealtimeEnv()
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
    return new Response("v=0\r\n", { status: 200 })
  }

  try {
    const response = await handler(new Request("https://functions.test/realtime-session", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sdp: "v=0\r\n" }),
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
    clearRealtimeEnv()
  }
})

Deno.test("realtime usage reservation failures do not call OpenAI or misclassify database limits", async () => {
  clearRealtimeEnv()
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
    if (url.includes("/api/database/rpc/reserve_agent_usage_cost")) {
      calls.push("reserve")
      return new Response(JSON.stringify({ error: { message: "database connection limit reached Authorization: Bearer leaked-token" } }), {
        status: 429,
        headers: { "Content-Type": "application/json" },
      })
    }

    calls.push("openai")
    return new Response("v=0\r\n", { status: 200 })
  }

  try {
    const response = await handler(new Request("https://functions.test/realtime-session", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sdp: "v=0\r\n" }),
    }))
    const text = await response.text()
    const body = JSON.parse(text)

    assertEquals(response.status, 500)
    assertEquals(body.error, "The request failed. Please try again.")
    assertEquals(calls, ["auth", "reserve"])
    assertEquals(text.includes("Bearer"), false)
    assertEquals(text.includes("leaked-token"), false)
  } finally {
    globalThis.fetch = originalFetch
    clearRealtimeEnv()
  }
})

Deno.test("realtime usage limits return clear account-limit responses before OpenAI", async () => {
  clearRealtimeEnv()
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
    if (url.includes("/api/database/rpc/reserve_agent_usage_cost")) {
      calls.push("reserve")
      return new Response(JSON.stringify({ error: { message: "Daily realtime usage cap reached for default tier" } }), {
        status: 429,
        headers: { "Content-Type": "application/json" },
      })
    }

    calls.push("openai")
    return new Response("v=0\r\n", { status: 200 })
  }

  try {
    const response = await handler(new Request("https://functions.test/realtime-session", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sdp: "v=0\r\n" }),
    }))
    const body = await response.json()

    assertEquals(response.status, 402)
    assertEquals(body.code, "usage_limit_reached")
    assertEquals(body.error, "Daily realtime usage cap reached for default tier")
    assertEquals(calls, ["auth", "reserve"])
  } finally {
    globalThis.fetch = originalFetch
    clearRealtimeEnv()
  }
})

Deno.test("realtime upstream errors do not expose secrets to the client", async () => {
  clearRealtimeEnv()
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

    return new Response(JSON.stringify({ error: { message: `upstream leaked ${leakedSecret}` } }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/realtime-session", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sdp: "v=0\r\n" }),
    }))
    const text = await response.text()
    const body = JSON.parse(text)

    assertEquals(response.status, 502)
    assertEquals(body.error, "The AI service is temporarily unavailable. Please try again.")
    assertEquals(text.includes("not-real-secret"), false)
    assertEquals(text.includes("OPENAI_API_KEY"), false)
    assertEquals("upstreamBody" in body, false)
  } finally {
    globalThis.fetch = originalFetch
    clearRealtimeEnv()
  }
})

Deno.test("realtime preserves OpenAI auth and rate-limit status without leaking upstream body", async () => {
  for (const upstreamStatus of [401, 429]) {
    clearRealtimeEnv()
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

      return new Response(JSON.stringify({ error: { message: `upstream ${upstreamStatus} quota OPENAI_API_KEY=redacted-test` } }), {
        status: upstreamStatus,
        headers: { "Content-Type": "application/json" },
      })
    }

    try {
      const response = await handler(new Request("https://functions.test/realtime-session", {
        method: "POST",
        headers: {
          Authorization: "Bearer user-token",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ sdp: "v=0\r\n" }),
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
      clearRealtimeEnv()
    }
  }
})

Deno.test("realtime reserves and finalizes usage caps when enabled", async () => {
  clearRealtimeEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")
  Deno.env.set("VOIYCE_ENFORCE_AGENT_USAGE_CAPS", "true")
  Deno.env.set("VOIYCE_REALTIME_ESTIMATED_SESSION_COST_USD", "0.07")
  Deno.env.set("VOIYCE_REALTIME_ESTIMATED_SESSION_SECONDS", "420")

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
    return new Response("v=0\r\nanswer", { status: 200 })
  }

  try {
    const response = await handler(new Request("https://functions.test/realtime-session", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sdp: "v=0\r\n" }),
    }))
    const body = await response.json()

    assertEquals(response.status, 200)
    assertEquals(body.sdp, "v=0\r\nanswer")
    assertEquals(calls.map((call) => call.kind), ["auth", "reserve", "openai", "finalize"])
    assertEquals(calls[1].body, {
      p_user_id: "user_123",
      p_capability: "realtime",
      p_estimated_cost_usd: 0.07,
      p_usage_units: {
        session_count: 1,
        estimated_session_seconds: 420,
        sdp_chars: 5,
      },
    })
    assertEquals(calls[3].body, {
      p_usage_id: "usage_123",
      p_succeeded: true,
    })
  } finally {
    globalThis.fetch = originalFetch
    clearRealtimeEnv()
  }
})
