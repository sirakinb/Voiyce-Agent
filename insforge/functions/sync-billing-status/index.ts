const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
}

type CheckoutPlan = 'monthly' | 'yearly'

type AuthUser = {
  id: string
}

type BillingProfile = {
  user_id: string
  stripe_customer_id?: string | null
}

type StripeSubscription = {
  id?: string
  status?: string
  customer?: string
  created?: number
  metadata?: {
    voiyce_plan?: string
  }
  cancel_at_period_end?: boolean
  current_period_end?: number
  items?: {
    data?: Array<{
      price?: {
        id?: string
        recurring?: {
          interval?: string
        }
      }
    }>
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

async function stripeRequest(secretKey: string, customerId: string): Promise<StripeSubscription | null> {
  const params = new URLSearchParams({
    customer: customerId,
    status: 'all',
    limit: '10'
  })

  const data = await fetchJSON(`https://api.stripe.com/v1/subscriptions?${params.toString()}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${secretKey}`
    }
  }) as { data?: StripeSubscription[] }

  const subscriptions = data.data ?? []
  if (subscriptions.length === 0) {
    return null
  }

  const statusPriority = new Map<string, number>([
    ['active', 4],
    ['trialing', 3],
    ['past_due', 2],
    ['unpaid', 1],
    ['canceled', 0],
    ['incomplete', 0],
    ['incomplete_expired', 0],
    ['paused', 0]
  ])

  return subscriptions
    .slice()
    .sort((left, right) => {
      const leftPriority = statusPriority.get(left.status ?? '') ?? 0
      const rightPriority = statusPriority.get(right.status ?? '') ?? 0

      if (leftPriority != rightPriority) {
        return rightPriority - leftPriority
      }

      return (right.created ?? 0) - (left.created ?? 0)
    })[0] ?? null
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

    let profile = await findBillingProfile(baseUrl, apiKey, user.id)

    if (!profile) {
      profile = await insertBillingProfile(baseUrl, apiKey, { user_id: user.id })
    }

    const stripeCustomerId = profile?.stripe_customer_id
    if (!stripeCustomerId) {
      return json({ synced: true, hasSubscription: false })
    }

    const subscription = await stripeRequest(stripeSecretKey, stripeCustomerId)

    if (!subscription?.id) {
      await updateBillingProfile(baseUrl, apiKey, user.id, {
        stripe_subscription_id: null,
        subscription_status: 'inactive',
        stripe_price_id: null,
        current_period_end: null,
        cancel_at_period_end: false,
        active_plan: null
      })

      return json({ synced: true, hasSubscription: false })
    }

    const hasActiveSubscription = ['active', 'trialing', 'past_due'].includes(subscription.status ?? '')
    const activePlan = deriveActivePlan(
      subscription.metadata?.voiyce_plan,
      subscription.items?.data?.[0]?.price?.recurring?.interval
    )

    await updateBillingProfile(baseUrl, apiKey, user.id, {
      stripe_customer_id: stripeCustomerId,
      stripe_subscription_id: subscription.id ?? null,
      subscription_status: subscription.status ?? 'inactive',
      stripe_price_id: subscription.items?.data?.[0]?.price?.id ?? null,
      current_period_end: typeof subscription.current_period_end === 'number'
        ? new Date(subscription.current_period_end * 1000).toISOString()
        : null,
      cancel_at_period_end: Boolean(subscription.cancel_at_period_end),
      active_plan: hasActiveSubscription ? activePlan : null
    })

    return json({
      synced: true,
      hasSubscription: hasActiveSubscription
    })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unknown error' }, 500)
  }
}
