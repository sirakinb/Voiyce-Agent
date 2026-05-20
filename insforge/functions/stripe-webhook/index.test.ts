import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts"
import handler from "./index.ts"

function clearWebhookEnv() {
  for (const name of [
    "INSFORGE_BASE_URL",
    "API_KEY",
    "STRIPE_WEBHOOK_SECRET",
  ]) {
    Deno.env.delete(name)
  }
}

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("")
}

async function stripeSignature(payload: string, secret: string): Promise<string> {
  const timestamp = Math.floor(Date.now() / 1000)
  const encoder = new TextEncoder()
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  )
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${timestamp}.${payload}`),
  )

  return `t=${timestamp},v1=${toHex(signature)}`
}

Deno.test("stripe webhook rejects missing signatures before database calls", async () => {
  clearWebhookEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("API_KEY", "insforge-service-key")
  Deno.env.set("STRIPE_WEBHOOK_SECRET", "whsec_test")

  const originalFetch = globalThis.fetch
  globalThis.fetch = () => {
    throw new Error("fetch should not run without Stripe-Signature")
  }

  try {
    const response = await handler(new Request("https://functions.test/stripe-webhook", {
      method: "POST",
      body: JSON.stringify({ type: "customer.subscription.updated" }),
    }))
    const body = await response.json()

    assertEquals(response.status, 400)
    assertStringIncludes(body.error, "Missing Stripe-Signature")
  } finally {
    globalThis.fetch = originalFetch
    clearWebhookEnv()
  }
})

Deno.test("stripe webhook ignores unrelated signed events without billing updates", async () => {
  clearWebhookEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test")
  Deno.env.set("API_KEY", "insforge-service-key")
  Deno.env.set("STRIPE_WEBHOOK_SECRET", "whsec_test")

  const payload = JSON.stringify({ type: "checkout.session.completed", data: { object: {} } })
  const signature = await stripeSignature(payload, "whsec_test")
  const originalFetch = globalThis.fetch
  globalThis.fetch = () => {
    throw new Error("fetch should not run for ignored Stripe events")
  }

  try {
    const response = await handler(new Request("https://functions.test/stripe-webhook", {
      method: "POST",
      headers: { "Stripe-Signature": signature },
      body: payload,
    }))
    const body = await response.json()

    assertEquals(response.status, 200)
    assertEquals(body, { received: true, ignored: true })
  } finally {
    globalThis.fetch = originalFetch
    clearWebhookEnv()
  }
})

Deno.test("stripe webhook maps subscription updates into billing RPC payloads", async () => {
  clearWebhookEnv()
  Deno.env.set("INSFORGE_BASE_URL", "https://insforge.test/")
  Deno.env.set("API_KEY", "insforge-service-key")
  Deno.env.set("STRIPE_WEBHOOK_SECRET", "whsec_test")

  const payload = JSON.stringify({
    type: "customer.subscription.updated",
    data: {
      object: {
        id: "sub_123",
        customer: { id: "cus_123" },
        status: "active",
        current_period_end: 1780000000,
        cancel_at_period_end: true,
        metadata: {
          insforge_user_id: "00000000-0000-4000-8000-000000000001",
        },
        items: {
          data: [{
            price: {
              id: "price_yearly",
              recurring: { interval: "year" },
            },
          }],
        },
      },
    },
  })
  const signature = await stripeSignature(payload, "whsec_test")
  const calls: Array<{ url: string; init?: RequestInit }> = []
  const originalFetch = globalThis.fetch
  globalThis.fetch = async (input, init) => {
    calls.push({ url: String(input), init })
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    const response = await handler(new Request("https://functions.test/stripe-webhook", {
      method: "POST",
      headers: { "Stripe-Signature": signature },
      body: payload,
    }))
    const body = await response.json()
    const rpcBody = JSON.parse(String(calls[0]?.init?.body))

    assertEquals(response.status, 200)
    assertEquals(body, { received: true })
    assertEquals(calls.length, 1)
    assertEquals(calls[0].url, "https://insforge.test/api/database/rpc/apply_stripe_subscription_update")
    assertEquals(calls[0].init?.method, "POST")
    assertEquals((calls[0].init?.headers as Record<string, string>).Authorization, "Bearer insforge-service-key")
    assertEquals(rpcBody, {
      p_user_id: "00000000-0000-4000-8000-000000000001",
      p_customer_id: "cus_123",
      p_subscription_id: "sub_123",
      p_subscription_status: "active",
      p_price_id: "price_yearly",
      p_current_period_end: "2026-05-28T20:26:40.000Z",
      p_cancel_at_period_end: true,
      p_active_plan: "yearly",
    })
  } finally {
    globalThis.fetch = originalFetch
    clearWebhookEnv()
  }
})
