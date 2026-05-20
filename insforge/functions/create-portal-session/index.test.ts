import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts"
import handler from "./index.ts"

function clearStripeEnv() {
  for (const name of [
    "INSFORGE_BASE_URL",
    "API_KEY",
    "STRIPE_SECRET_KEY",
    "STRIPE_ALLOW_LIVE_MODE",
  ]) {
    Deno.env.delete(name)
  }
}

Deno.test("billing portal blocks Stripe live mode unless explicitly acknowledged", async () => {
  clearStripeEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("API_KEY", "insforge-service-key")
  Deno.env.set("STRIPE_SECRET_KEY", ["sk", "live"].join("_") + "_not_real")

  const originalFetch = globalThis.fetch
  globalThis.fetch = () => {
    throw new Error("fetch should not run before Stripe mode review")
  }

  try {
    const response = await handler(new Request("https://functions.test/create-portal-session", {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
      },
    }))
    const body = await response.json()

    assertEquals(response.status, 500)
    assertStringIncludes(body.error, "Stripe live mode is disabled")
  } finally {
    globalThis.fetch = originalFetch
    clearStripeEnv()
  }
})
