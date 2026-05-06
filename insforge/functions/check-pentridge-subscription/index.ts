const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
}

const PENTRIDGE_LABS_URL = 'https://3nm75tby.us-east.insforge.app/functions/check-subscription'

type AuthUser = {
  id: string
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

async function checkPentridgeSubscription(userToken: string): Promise<PentridgeResponse> {
  const response = await fetch(PENTRIDGE_LABS_URL, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${userToken}`
    }
  })

  if (!response.ok) {
    return { has_subscription: false, tier: null }
  }

  const data = await response.json() as PentridgeResponse
  return {
    has_subscription: Boolean(data.has_subscription),
    tier: data.has_subscription ? (data.tier ?? null) : null
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

    const result = await checkPentridgeSubscription(userToken!)

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
