const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
}

type AuthUser = {
  id: string
}

type BillingProfile = {
  stripe_customer_id?: string | null
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

async function stripeRequest(
  secretKey: string,
  path: string,
  params: URLSearchParams
): Promise<Record<string, unknown>> {
  return await fetchJSON(`https://api.stripe.com${path}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${secretKey}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: params.toString()
  }) as Record<string, unknown>
}

export default async function(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  try {
    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const apiKey = requireEnv('API_KEY')
    const stripeSecretKey = requireEnv('STRIPE_SECRET_KEY')
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null

    const user = await getCurrentUser(baseUrl, userToken)
    if (!user?.id) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const params = new URLSearchParams({
      select: '*',
      user_id: `eq.${user.id}`,
      limit: '1'
    })

    const profiles = await fetchJSON(
      `${baseUrl.replace(/\/$/, '')}/api/database/records/billing_profiles?${params.toString()}`,
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${apiKey}`
        }
      }
    ) as BillingProfile[]

    const profile = profiles[0] ?? null
    const stripeCustomerId = profile?.stripe_customer_id

    if (!stripeCustomerId) {
      return json({ error: 'No Stripe customer is linked to this account yet. Start checkout first.' }, 400)
    }

    const billingReturnBase = `${baseUrl.replace(/\/$/, '')}/functions/billing-return`
    const sessionParams = new URLSearchParams()
    sessionParams.set('customer', stripeCustomerId)
    sessionParams.set('return_url', `${billingReturnBase}?state=portal`)

    const session = await stripeRequest(stripeSecretKey, '/v1/billing_portal/sessions', sessionParams)
    const sessionURL = typeof session.url === 'string' ? session.url : null

    if (!sessionURL) {
      return json({ error: 'Stripe did not return a portal URL.' }, 500)
    }

    return json({ url: sessionURL })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unknown error' }, 500)
  }
}
