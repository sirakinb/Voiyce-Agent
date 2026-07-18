import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts"
import handler from "./index.ts"

function clearVideoDBEnv() {
  for (const name of [
    "INSFORGE_BASE_URL",
    "VIDEO_DB_API_KEY",
    "VIDEODB_API_KEY",
    "VOIYCE_DISABLE_SESSION_CONTEXT",
    "VOIYCE_SESSION_CONTEXT_MAX_QUERY_CHARS",
  ]) {
    Deno.env.delete(name)
  }
}

function signedRequest(body: unknown): Request {
  return new Request("https://functions.test/videodb-session", {
    method: "POST",
    headers: {
      Authorization: "Bearer user-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  })
}

Deno.test("videodb session handles CORS preflight and unsupported methods before env lookup", async () => {
  clearVideoDBEnv()

  const optionsResponse = await handler(new Request("https://functions.test/videodb-session", {
    method: "OPTIONS",
  }))
  assertEquals(optionsResponse.status, 204)
  assertStringIncludes(optionsResponse.headers.get("Access-Control-Allow-Methods") ?? "", "POST")

  const getResponse = await handler(new Request("https://functions.test/videodb-session", {
    method: "GET",
  }))
  const body = await getResponse.json()
  assertEquals(getResponse.status, 405)
  assertEquals(body.error, "Method not allowed")
})

Deno.test("videodb session kill switch returns disabled response before env lookup", async () => {
  clearVideoDBEnv()
  Deno.env.set("VOIYCE_DISABLE_SESSION_CONTEXT", "true")

  try {
    const response = await handler(new Request("https://functions.test/videodb-session", {
      method: "POST",
      body: JSON.stringify({ action: "create" }),
    }))
    const body = await response.json()

    assertEquals(response.status, 503)
    assertEquals(body.code, "capability_disabled")
    assertStringIncludes(body.displayMessage, "Session context")
  } finally {
    clearVideoDBEnv()
  }
})

Deno.test("videodb session auth provider failures do not call VideoDB or leak auth payloads", async () => {
  clearVideoDBEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("VIDEO_DB_API_KEY", "videodb-test-key")

  const calls: string[] = []
  const originalFetch = globalThis.fetch
  globalThis.fetch = async (input) => {
    const url = String(input)
    if (url.includes("/api/auth/sessions/current")) {
      calls.push("auth")
      return new Response(JSON.stringify({ error: { message: "auth failed Authorization: Bearer leaked-token" } }), {
        status: 503,
        headers: { "Content-Type": "application/json" },
      })
    }

    calls.push("videodb")
    return new Response(JSON.stringify({ data: {} }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(signedRequest({ action: "create" }))
    const text = await response.text()
    const body = JSON.parse(text)

    assertEquals(response.status, 500)
    assertEquals(body.error, "The request failed. Please try again.")
    assertEquals(calls, ["auth"])
    assertEquals(text.includes("Bearer"), false)
    assertEquals(text.includes("leaked-token"), false)
  } finally {
    globalThis.fetch = originalFetch
    clearVideoDBEnv()
  }
})

Deno.test("videodb session validation failures are client-safe and avoid upstream calls", async () => {
  clearVideoDBEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("VIDEO_DB_API_KEY", "videodb-test-key")

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

    calls.push("videodb")
    return new Response(JSON.stringify({ data: {} }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(signedRequest({ action: "start_scene_index" }))
    const body = await response.json()

    assertEquals(response.status, 400)
    assertEquals(body.error, "displayStreamID is required.")
    assertEquals(calls, ["auth"])
  } finally {
    globalThis.fetch = originalFetch
    clearVideoDBEnv()
  }
})

Deno.test("videodb session enforces search query cap before upstream calls", async () => {
  clearVideoDBEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("VIDEO_DB_API_KEY", "videodb-test-key")
  Deno.env.set("VOIYCE_SESSION_CONTEXT_MAX_QUERY_CHARS", "4")

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

    calls.push("videodb")
    return new Response(JSON.stringify({ data: {} }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(signedRequest({
      action: "search",
      displayStreamID: "display_123",
      sceneIndexID: "scene_123",
      query: "too long",
    }))
    const body = await response.json()

    assertEquals(response.status, 413)
    assertStringIncludes(body.error, "Session context search query exceeds 4 characters")
    assertEquals(calls, ["auth"])
  } finally {
    globalThis.fetch = originalFetch
    clearVideoDBEnv()
  }
})

Deno.test("videodb session upstream failures return generic client errors", async () => {
  clearVideoDBEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("VIDEO_DB_API_KEY", "videodb-test-key")

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

    calls.push("videodb")
    return new Response(JSON.stringify({
      error: {
        message: "VideoDB rejected x-access-token=secret-token Authorization: Bearer leaked-token",
      },
    }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(signedRequest({
      action: "start_scene_index",
      displayStreamID: "display_123",
    }))
    const text = await response.text()
    const body = JSON.parse(text)

    assertEquals(response.status, 502)
    assertEquals(body.error, "The request failed. Please try again.")
    assertEquals(body.upstreamStatus, 500)
    assertEquals(calls, ["auth", "videodb"])
    assertEquals(text.includes("secret-token"), false)
    assertEquals(text.includes("leaked-token"), false)
    assertEquals(text.includes("VideoDB rejected"), false)
  } finally {
    globalThis.fetch = originalFetch
    clearVideoDBEnv()
  }
})
