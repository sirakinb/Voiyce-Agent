import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts"
import handler from "./index.ts"

function clearScreenContextEnv() {
  for (const name of [
    "INSFORGE_BASE_URL",
    "OPENAI_API_KEY",
    "VOIYCE_DISABLE_ALL_AI",
    "VOIYCE_DISABLE_SCREEN_CONTEXT",
    "VOIYCE_ENFORCE_AGENT_USAGE_CAPS",
    "VOIYCE_SCREEN_CONTEXT_MAX_IMAGE_BASE64_CHARS",
    "VOIYCE_SCREEN_CONTEXT_ESTIMATED_REQUEST_COST_USD",
  ]) {
    Deno.env.delete(name)
  }
}

Deno.test("screen context kill switch returns a disabled response before env lookup", async () => {
  clearScreenContextEnv()
  Deno.env.set("VOIYCE_DISABLE_SCREEN_CONTEXT", "true")

  try {
    const response = await handler(new Request("https://functions.test/screen-context", {
      method: "POST",
    }))
    const body = await response.json()

    assertEquals(response.status, 503)
    assertEquals(body.code, "capability_disabled")
    assertStringIncludes(body.displayMessage, "Screen context")
  } finally {
    clearScreenContextEnv()
  }
})

Deno.test("global AI kill switch disables screen context", async () => {
  clearScreenContextEnv()
  Deno.env.set("VOIYCE_DISABLE_ALL_AI", "1")

  try {
    const response = await handler(new Request("https://functions.test/screen-context", {
      method: "POST",
    }))
    const body = await response.json()

    assertEquals(response.status, 503)
    assertEquals(body.code, "capability_disabled")
  } finally {
    clearScreenContextEnv()
  }
})

Deno.test("screen context handles CORS preflight and unsupported methods before env lookup", async () => {
  clearScreenContextEnv()

  const optionsResponse = await handler(new Request("https://functions.test/screen-context", {
    method: "OPTIONS",
  }))
  assertEquals(optionsResponse.status, 204)
  assertStringIncludes(optionsResponse.headers.get("Access-Control-Allow-Methods") ?? "", "POST")

  const getResponse = await handler(new Request("https://functions.test/screen-context", {
    method: "GET",
  }))
  const body = await getResponse.json()
  assertEquals(getResponse.status, 405)
  assertEquals(body.error, "Method not allowed")
})

Deno.test("screen context enforces image size before calling OpenAI", async () => {
  clearScreenContextEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")
  Deno.env.set("VOIYCE_SCREEN_CONTEXT_MAX_IMAGE_BASE64_CHARS", "4")

  const originalFetch = globalThis.fetch
  globalThis.fetch = async () =>
    new Response(JSON.stringify({ user: { id: "user_123" } }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })

  try {
    const response = await handler(new Request("https://functions.test/screen-context", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ imageBase64: "0123456789" }),
    }))
    const body = await response.json()

    assertEquals(response.status, 413)
    assertStringIncludes(body.error, "Screen context image exceeds")
  } finally {
    globalThis.fetch = originalFetch
    clearScreenContextEnv()
  }
})

Deno.test("screen context auth provider failures do not call OpenAI or leak auth payloads", async () => {
  clearScreenContextEnv()
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
    return new Response(JSON.stringify({ output_text: "should not run" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/screen-context", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ imageBase64: "abc123" }),
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
    clearScreenContextEnv()
  }
})

Deno.test("screen context usage reservation failures do not call OpenAI or leak database payloads", async () => {
  clearScreenContextEnv()
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
      return new Response(JSON.stringify({ error: { message: "database failed Authorization: Bearer leaked-token" } }), {
        status: 503,
        headers: { "Content-Type": "application/json" },
      })
    }

    calls.push("openai")
    return new Response(JSON.stringify({ output_text: "should not run" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/screen-context", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ imageBase64: "abc123" }),
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
    clearScreenContextEnv()
  }
})

Deno.test("screen context usage limits return clear account-limit responses before OpenAI", async () => {
  clearScreenContextEnv()
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
      return new Response(JSON.stringify({ error: { message: "Daily context usage cap reached for default tier" } }), {
        status: 429,
        headers: { "Content-Type": "application/json" },
      })
    }

    calls.push("openai")
    return new Response(JSON.stringify({ output_text: "should not run" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/screen-context", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ imageBase64: "abc123" }),
    }))
    const body = await response.json()

    assertEquals(response.status, 402)
    assertEquals(body.code, "usage_limit_reached")
    assertEquals(body.error, "Daily context usage cap reached for default tier")
    assertEquals(calls, ["auth", "reserve"])
  } finally {
    globalThis.fetch = originalFetch
    clearScreenContextEnv()
  }
})

Deno.test("screen context upstream errors do not expose secrets to the client", async () => {
  clearScreenContextEnv()
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
    const response = await handler(new Request("https://functions.test/screen-context", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ imageBase64: "abc123" }),
    }))
    const text = await response.text()
    const body = JSON.parse(text)

    assertEquals(response.status, 502)
    assertEquals(body.error, "The AI service is temporarily unavailable. Please try again.")
    assertEquals(text.includes("not-real-secret"), false)
    assertEquals(text.includes("OPENAI_API_KEY"), false)
  } finally {
    globalThis.fetch = originalFetch
    clearScreenContextEnv()
  }
})

Deno.test("screen context preserves OpenAI auth and rate-limit status without leaking upstream payload", async () => {
  for (const upstreamStatus of [401, 429]) {
    clearScreenContextEnv()
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
      const response = await handler(new Request("https://functions.test/screen-context", {
        method: "POST",
        headers: {
          Authorization: "Bearer user-token",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ imageBase64: "abc123" }),
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
      clearScreenContextEnv()
    }
  }
})

Deno.test("screen context reserves and finalizes usage caps when enabled", async () => {
  clearScreenContextEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("OPENAI_API_KEY", "test-openai-key")
  Deno.env.set("VOIYCE_ENFORCE_AGENT_USAGE_CAPS", "true")
  Deno.env.set("VOIYCE_SCREEN_CONTEXT_ESTIMATED_REQUEST_COST_USD", "0.004")

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
    return new Response(JSON.stringify({
      output_text: JSON.stringify({
        summary: "Dashboard is visible.",
        visible_text: "Pro Trial",
        actionable_context: "The user is on the dashboard.",
      }),
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/screen-context", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ imageBase64: "abc123" }),
    }))
    const body = await response.json()

    assertEquals(response.status, 200)
    assertEquals(body.summary, "Dashboard is visible.")
    assertEquals(calls.map((call) => call.kind), ["auth", "reserve", "openai", "finalize"])
    assertEquals(calls[1].body, {
      p_user_id: "user_123",
      p_capability: "context",
      p_estimated_cost_usd: 0.004,
      p_usage_units: {
        request_count: 1,
        screenshot_count: 1,
        image_base64_chars: 6,
        prompt_chars: 0,
      },
    })
    assertEquals(calls[3].body, {
      p_usage_id: "usage_123",
      p_succeeded: true,
    })
  } finally {
    globalThis.fetch = originalFetch
    clearScreenContextEnv()
  }
})
