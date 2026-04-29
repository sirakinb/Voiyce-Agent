const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
}

const MONTHLY_PRODUCT_NAME = 'Voiyce Pro Monthly'
const YEARLY_PRODUCT_NAME = 'Voiyce Pro Yearly'
const PRODUCT_DESCRIPTION = 'Unlimited dictation with prioritized support and early access to new features.'
const MONTHLY_PRICE_CENTS = 1200
const YEARLY_PRICE_CENTS = 12000
const MONTHLY_PRICE_CURRENCY = 'usd'

type CheckoutPlan = 'monthly' | 'yearly'

type AuthUser = {
  id: string
  email?: string | null
  name?: string | null
}

type BillingProfile = {
  user_id: string
  stripe_customer_id?: string | null
  preferred_plan?: CheckoutPlan | null
}

type CheckoutRequest = {
  plan?: string
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

async function findBillingProfile(baseUrl: string, apiKey: string, column: string, value: string): Promise<BillingProfile | null> {
  const params = new URLSearchParams({
    select: '*',
    [column]: `eq.${value}`,
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

async function parseCheckoutPlan(req: Request): Promise<CheckoutPlan> {
  const rawBody = await req.text()

  if (!rawBody.trim()) {
    return 'monthly'
  }

  const body = JSON.parse(rawBody) as CheckoutRequest
  return body.plan === 'yearly' ? 'yearly' : 'monthly'
}

export default async function(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  try {
    const selectedPlan = await parseCheckoutPlan(req)
    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const apiKey = requireEnv('API_KEY')
    const stripeSecretKey = requireEnv('STRIPE_SECRET_KEY')
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null

    const user = await getCurrentUser(baseUrl, userToken)
    if (!user?.id) {
      return json({ error: 'Unauthorized' }, 401)
    }

    let profile = await findBillingProfile(baseUrl, apiKey, 'user_id', user.id)

    if (!profile) {
      profile = await insertBillingProfile(baseUrl, apiKey, {
        user_id: user.id,
        preferred_plan: selectedPlan,
        preferred_plan_updated_at: new Date().toISOString()
      })
    } else {
      await updateBillingProfile(baseUrl, apiKey, user.id, {
        preferred_plan: selectedPlan,
        preferred_plan_updated_at: new Date().toISOString()
      })

      profile = await findBillingProfile(baseUrl, apiKey, 'user_id', user.id)
    }

    let stripeCustomerId = profile?.stripe_customer_id ?? null

    if (!stripeCustomerId) {
      const customerParams = new URLSearchParams()
      if (user.email) customerParams.set('email', user.email)
      if (user.name) customerParams.set('name', user.name)
      customerParams.set('metadata[insforge_user_id]', user.id)

      const customer = await stripeRequest(stripeSecretKey, '/v1/customers', customerParams)
      stripeCustomerId = typeof customer.id === 'string' ? customer.id : null

      if (!stripeCustomerId) {
        return json({ error: 'Stripe did not return a customer ID.' }, 500)
      }

      await updateBillingProfile(baseUrl, apiKey, user.id, {
        stripe_customer_id: stripeCustomerId
      })
    }

    const configuredMonthlyPriceId = Deno.env.get('STRIPE_MONTHLY_PRICE_ID') ?? Deno.env.get('STRIPE_PRICE_ID')
    const configuredYearlyPriceId = Deno.env.get('STRIPE_YEARLY_PRICE_ID')
    const billingReturnBase = `${baseUrl.replace(/\/$/, '')}/functions/billing-return`
    const sessionParams = new URLSearchParams()

    sessionParams.set('mode', 'subscription')
    sessionParams.set('customer', stripeCustomerId)
    sessionParams.set('client_reference_id', user.id)
    sessionParams.set('success_url', `${billingReturnBase}?state=success&session_id={CHECKOUT_SESSION_ID}`)
    sessionParams.set('cancel_url', `${billingReturnBase}?state=cancelled`)
    sessionParams.set('allow_promotion_codes', 'false')
    sessionParams.set('metadata[insforge_user_id]', user.id)
    sessionParams.set('metadata[voiyce_plan]', selectedPlan)
    sessionParams.set('subscription_data[metadata][insforge_user_id]', user.id)
    sessionParams.set('subscription_data[metadata][voiyce_plan]', selectedPlan)
    sessionParams.set('line_items[0][quantity]', '1')

    const configuredPriceId = selectedPlan === 'yearly'
      ? configuredYearlyPriceId
      : configuredMonthlyPriceId

    if (configuredPriceId) {
      sessionParams.set('line_items[0][price]', configuredPriceId)
    } else {
      sessionParams.set('line_items[0][price_data][currency]', MONTHLY_PRICE_CURRENCY)
      sessionParams.set(
        'line_items[0][price_data][unit_amount]',
        String(selectedPlan === 'yearly' ? YEARLY_PRICE_CENTS : MONTHLY_PRICE_CENTS)
      )
      sessionParams.set(
        'line_items[0][price_data][recurring][interval]',
        selectedPlan === 'yearly' ? 'year' : 'month'
      )
      sessionParams.set(
        'line_items[0][price_data][product_data][name]',
        selectedPlan === 'yearly' ? YEARLY_PRODUCT_NAME : MONTHLY_PRODUCT_NAME
      )
      sessionParams.set('line_items[0][price_data][product_data][description]', PRODUCT_DESCRIPTION)
    }

    const session = await stripeRequest(stripeSecretKey, '/v1/checkout/sessions', sessionParams)
    const sessionURL = typeof session.url === 'string' ? session.url : null

    if (!sessionURL) {
      return json({ error: 'Stripe did not return a Checkout URL.' }, 500)
    }

    return json({ url: sessionURL })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unknown error' }, 500)
  }
}
