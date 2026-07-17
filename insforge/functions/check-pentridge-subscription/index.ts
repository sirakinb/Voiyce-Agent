const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
}

const PENTRIDGE_LABS_URL = 'https://3nm75tby.us-east.insforge.app/functions/check-subscription-public'

const INTERNAL_EMAIL_ALLOWLIST = new Set([
  'aki.b@pentridgemedia.com',
  'sirakinb@gmail.com',
  'dropcardai@gmail.com',
  'bajulaiye@protonmail.com',
  'raichellaram@gmail.com',
  '08lin.kevin121@gmail.com',
  'tyronepeace.qa@gmail.com',
  'jyho0243@gmail.com',
  'astrid.nigrovic@gmail.com'
])

type AuthUser = {
  id: string
  email?: string | null
}

type PentridgeResponse = {
  has_subscription: boolean
  tier?: 'standard' | 'pro' | null
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

async function getCurrentUser(baseUrl: string, userToken: string | null): Promise<AuthUser | null> {
  if (!userToken) {
    return null
  }

  const response = await fetch(
    `${baseUrl.replace(/\/$/, '')}/api/auth/sessions/current`,
    {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${userToken}`
      }
    }
  )

  if (!response.ok) {
    return null
  }

  const data = await response.json() as { user?: AuthUser }
  return data.user ?? null
}

// Returns null when the hub is unreachable, so callers can distinguish
// "hub said no" (revoke) from "hub down" (keep cached entitlement).
async function checkPentridgeSubscription(email: string): Promise<PentridgeResponse | null> {
  const normalizedEmail = email.trim().toLowerCase()

  if (INTERNAL_EMAIL_ALLOWLIST.has(normalizedEmail)) {
    return { has_subscription: true, tier: 'pro' }
  }

  try {
    const response = await fetch(PENTRIDGE_LABS_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: normalizedEmail })
    })

    if (!response.ok) {
      return null
    }

    const data = await response.json() as PentridgeResponse
    return {
      has_subscription: Boolean(data.has_subscription),
      tier: data.has_subscription ? (data.tier ?? null) : null
    }
  } catch {
    return null
  }
}

async function getCachedPentridgeStatus(baseUrl: string, apiKey: string, userId: string): Promise<PentridgeResponse> {
  const params = new URLSearchParams({
    user_id: `eq.${userId}`,
    select: 'pentridge_subscription_active,pentridge_tier'
  })

  try {
    const response = await fetch(
      `${baseUrl.replace(/\/$/, '')}/api/database/records/billing_profiles?${params.toString()}`,
      {
        headers: { Authorization: `Bearer ${apiKey}` }
      }
    )

    if (!response.ok) {
      return { has_subscription: false, tier: null }
    }

    const rows = await response.json() as Array<{ pentridge_subscription_active?: boolean; pentridge_tier?: 'standard' | 'pro' | null }>
    const row = rows[0]
    if (!row) {
      return { has_subscription: false, tier: null }
    }

    return {
      has_subscription: Boolean(row.pentridge_subscription_active),
      tier: row.pentridge_subscription_active ? (row.pentridge_tier ?? null) : null
    }
  } catch {
    return { has_subscription: false, tier: null }
  }
}

async function updateBillingProfile(baseUrl: string, apiKey: string, userId: string, payload: Record<string, unknown>) {
  const params = new URLSearchParams({ user_id: `eq.${userId}` })

  await fetch(
    `${baseUrl.replace(/\/$/, '')}/api/database/records/billing_profiles?${params.toString()}`,
    {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    }
  )
}

export default async function(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  try {
    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const apiKey = requireEnv('API_KEY')
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null

    const user = await getCurrentUser(baseUrl, userToken)
    if (!user?.id) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const hubResult = user.email
      ? await checkPentridgeSubscription(user.email)
      : { has_subscription: false, tier: null }

    if (hubResult === null) {
      // Hub unreachable: keep the cached entitlement so an already-entitled
      // session keeps working, without granting a brand-new unlock.
      const cached = await getCachedPentridgeStatus(baseUrl, apiKey, user.id)
      return json({
        has_subscription: cached.has_subscription,
        tier: cached.tier ?? null
      })
    }

    const result = hubResult

    // Cache the result in the billing profile
    await updateBillingProfile(baseUrl, apiKey, user.id, {
      pentridge_subscription_active: result.has_subscription,
      pentridge_tier: result.tier ?? null,
      pentridge_checked_at: new Date().toISOString()
    })

    return json({
      has_subscription: result.has_subscription,
      tier: result.tier ?? null
    })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unknown error' }, 500)
  }
}
