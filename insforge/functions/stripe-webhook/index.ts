const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, Stripe-Signature'
}

const SIGNATURE_TOLERANCE_SECONDS = 300

type CheckoutPlan = 'monthly' | 'yearly'

type BillingProfile = {
  type?: string
  data?: {
    object?: Record<string, unknown>
  }
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name)
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`)
  }
  return value
}

function normalizePlan(value: unknown): CheckoutPlan | null {
  return value === 'monthly' || value === 'yearly' ? value : null
}

function planFromRecurringInterval(value: unknown): CheckoutPlan | null {
  if (value === 'month') {
    return 'monthly'
  }

  if (value === 'year') {
    return 'yearly'
  }

  return null
}

function deriveActivePlan(metadataPlan: unknown, recurringInterval: unknown): CheckoutPlan | null {
  return normalizePlan(metadataPlan) ?? planFromRecurringInterval(recurringInterval)
}

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((value) => value.toString(16).padStart(2, '0'))
    .join('')
}

function timingSafeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) {
    return false
  }

  let mismatch = 0

  for (let index = 0; index < left.length; index += 1) {
    mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index)
  }

  return mismatch === 0
}

async function fetchJSON(
  url: string,
  init: RequestInit
): Promise<unknown> {
  const response = await fetch(url, init)
  const text = await response.text()
  const data = text ? JSON.parse(text) : null

  if (!response.ok) {
    const message = typeof (data as { error?: { message?: string } } | null)?.error?.message === 'string'
      ? (data as { error: { message: string } }).error.message
      : typeof (data as { message?: string } | null)?.message === 'string'
        ? (data as { message: string }).message
        : `Request failed with status ${response.status}`
    throw new Error(message)
  }

  return data
}

async function verifyStripeSignature(payload: string, signatureHeader: string, webhookSecret: string) {
  const entries = signatureHeader.split(',').map((part) => part.trim())
  const timestamp = entries.find((entry) => entry.startsWith('t='))?.slice(2)
  const signatures = entries
    .filter((entry) => entry.startsWith('v1='))
    .map((entry) => entry.slice(3))

  if (!timestamp || signatures.length === 0) {
    throw new Error('Stripe signature header is malformed.')
  }

  const timestampNumber = Number(timestamp)
  const currentTimestamp = Math.floor(Date.now() / 1000)

  if (!Number.isFinite(timestampNumber) || Math.abs(currentTimestamp - timestampNumber) > SIGNATURE_TOLERANCE_SECONDS) {
    throw new Error('Stripe signature timestamp is outside the allowed tolerance.')
  }

  const encoder = new TextEncoder()
  const secretKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(webhookSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const expectedBuffer = await crypto.subtle.sign(
    'HMAC',
    secretKey,
    encoder.encode(`${timestamp}.${payload}`)
  )

  const expectedSignature = toHex(expectedBuffer)

  if (!signatures.some((signature) => timingSafeEqual(signature, expectedSignature))) {
    throw new Error('Stripe signature verification failed.')
  }
}

export default async function(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  try {
    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const apiKey = requireEnv('API_KEY')
    const stripeWebhookSecret = requireEnv('STRIPE_WEBHOOK_SECRET')
    const signature = req.headers.get('Stripe-Signature')

    if (!signature) {
      return json({ error: 'Missing Stripe-Signature header.' }, 400)
    }

    const payload = await req.text()
    await verifyStripeSignature(payload, signature, stripeWebhookSecret)

    const event = JSON.parse(payload) as BillingProfile
    const eventType = event.type ?? ''

    if (![
      'customer.subscription.created',
      'customer.subscription.updated',
      'customer.subscription.deleted'
    ].includes(eventType)) {
      return json({ received: true, ignored: true })
    }

    const subscription = event.data?.object ?? {}
    const customerId = typeof subscription.customer === 'string'
      ? subscription.customer
      : typeof subscription.customer === 'object' && subscription.customer !== null && 'id' in subscription.customer
        ? (subscription.customer as { id?: string }).id ?? null
        : null
    const metadata = typeof subscription.metadata === 'object' && subscription.metadata !== null
      ? subscription.metadata as { insforge_user_id?: string; voiyce_plan?: string }
      : {}
    const items = typeof subscription.items === 'object' && subscription.items !== null
      ? subscription.items as { data?: Array<{ price?: { id?: string; recurring?: { interval?: string } } }> }
      : {}
    const firstPrice = items.data?.[0]?.price
    const currentPeriodEnd = typeof subscription.current_period_end === 'number'
      ? new Date(subscription.current_period_end * 1000).toISOString()
      : null
    const activePlan = deriveActivePlan(metadata.voiyce_plan, firstPrice?.recurring?.interval)

    await fetchJSON(
      `${baseUrl.replace(/\/$/, '')}/api/database/rpc/apply_stripe_subscription_update`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          p_user_id: metadata.insforge_user_id ?? null,
          p_customer_id: customerId,
          p_subscription_id: typeof subscription.id === 'string' ? subscription.id : null,
          p_subscription_status: typeof subscription.status === 'string' ? subscription.status : 'inactive',
          p_price_id: firstPrice?.id ?? null,
          p_current_period_end: currentPeriodEnd,
          p_cancel_at_period_end: Boolean(subscription.cancel_at_period_end),
          p_active_plan: activePlan
        })
      }
    )

    return json({ received: true })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unknown error' }, 400)
  }
}
