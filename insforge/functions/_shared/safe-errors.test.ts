import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { redactForLog, safeClientMessage } from "./safe-errors.ts"

Deno.test("safe error helpers redact bearer and access-token strings", () => {
  const fakeOpenAIKey = `${["sk", "proj"].join("-")}-not-real-secret`
  const redacted = redactForLog({
    message: `Authorization: Bearer leaked-token x-access-token=secret-token OPENAI_API_KEY=${fakeOpenAIKey}`,
    nested: {
      Authorization: "Bearer nested-token",
      detail: "API_KEY=server-secret",
    },
  }) as { message: string; nested: { Authorization: string; detail: string } }

  assertEquals(redacted.message.includes("leaked-token"), false)
  assertEquals(redacted.message.includes("secret-token"), false)
  assertEquals(redacted.message.includes(fakeOpenAIKey), false)
  assertEquals(redacted.nested.Authorization, "[redacted]")
  assertEquals(redacted.nested.detail.includes("server-secret"), false)
})

Deno.test("safe client messages replace sensitive payloads with generic copy", () => {
  assertEquals(
    safeClientMessage("Authorization: Bearer leaked-token"),
    "The request failed. Please try again.",
  )
  assertEquals(
    safeClientMessage("x-access-token=secret-token"),
    "The request failed. Please try again.",
  )
})
