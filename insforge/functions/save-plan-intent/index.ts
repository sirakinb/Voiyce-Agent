const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
}

type AuthUser = {
  id: string
}

type CheckoutPlan = 'monthly' | 'yearly'

type SavePlanIntentRequest = {
  plan?: string
}

type BillingProfile = {
  user_id: string
  preferred_plan?: CheckoutPlan | null
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

async function fetchJSON(url: string, init: RequestInit): Promise<unknown> {
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

async function getCurrentUser(baseUrl: string, userToken: string | null): Promise<AuthUser | null> {
  if (!userToken) {
    return null
  }

  const data = await fetchJSON(
    `${baseUrl.replace(/\/$/, '')}/api/auth/sessions/current`,
    {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${userToken}`
      }
    }
  ) as { user?: AuthUser }

  return data.user ?? null
}

async function findBillingProfile(baseUrl: string, apiKey: string, userId: string): Promise<BillingProfile | null> {
  const params = new URLSearchParams({
    select: '*',
    user_id: `eq.${userId}`,
    limit: '1'
  })

  const data = await fetchJSON(
    `${baseUrl.replace(/\/$/, '')}/api/database/records/billing_profiles?${params.toString()}`,
    {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${apiKey}`
      }
    }
  ) as BillingProfile[]

  return data[0] ?? null
}

async function insertBillingProfile(baseUrl: string, apiKey: string, payload: Record<string, unknown>): Promise<BillingProfile | null> {
  const data = await fetchJSON(
    `${baseUrl.replace(/\/$/, '')}/api/database/records/billing_profiles?select=*`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation'
      },
      body: JSON.stringify([payload])
    }
  ) as BillingProfile[]

  return data[0] ?? null
}

async function updateBillingProfile(baseUrl: string, apiKey: string, userId: string, payload: Record<string, unknown>) {
  const params = new URLSearchParams({
    user_id: `eq.${userId}`
  })

  await fetchJSON(
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

async function parsePlan(req: Request): Promise<CheckoutPlan> {
  const rawBody = await req.text()
  if (!rawBody.trim()) {
    throw new Error('plan is required')
  }

  const body = JSON.parse(rawBody) as SavePlanIntentRequest
  if (body.plan === 'monthly' || body.plan === 'yearly') {
    return body.plan
  }

  throw new Error('plan must be monthly or yearly')
}

export default async function(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  try {
    const plan = await parsePlan(req)
    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const apiKey = requireEnv('API_KEY')
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null

    const user = await getCurrentUser(baseUrl, userToken)
    if (!user?.id) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const existingProfile = await findBillingProfile(baseUrl, apiKey, user.id)

    if (!existingProfile) {
      await insertBillingProfile(baseUrl, apiKey, {
        user_id: user.id,
        preferred_plan: plan,
        preferred_plan_updated_at: new Date().toISOString()
      })
    } else {
      await updateBillingProfile(baseUrl, apiKey, user.id, {
        preferred_plan: plan,
        preferred_plan_updated_at: new Date().toISOString()
      })
    }

    return json({ saved: true, preferredPlan: plan })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unknown error' }, 500)
  }
}
