import {
  accountUsageLimitMessage,
  AI_SERVICE_UNAVAILABLE_ERROR,
  GENERIC_CLIENT_ERROR,
  isAccountUsageLimitMessage,
  redactForLog,
} from '../_shared/safe-errors.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
}

type ErrorSource = 'internal' | 'openai'

class HTTPStatusError extends Error {
  readonly status: number
  readonly source: ErrorSource

  constructor(status: number, message: string, source: ErrorSource = 'internal') {
    super(message)
    this.name = 'HTTPStatusError'
    this.status = status
    this.source = source
  }
}

type AuthUser = {
  id: string
}

type ScreenContextRequest = {
  prompt?: string
  imageBase64?: string
}

type OpenAITextItem = {
  type?: string
  text?: string
}

type OpenAIResponse = {
  output_text?: string
  output?: Array<{
    content?: OpenAITextItem[]
  }>
}

type UsageReservation = Array<{ usage_id?: string }> | { usage_id?: string } | null
type UsageUnits = Record<string, number | string | boolean>

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

function envFlag(name: string): boolean {
  return ['1', 'true', 'yes', 'on'].includes((Deno.env.get(name) ?? '').trim().toLowerCase())
}

function envNumber(name: string, fallback: number): number {
  const parsed = Number(Deno.env.get(name))
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback
}

function statusForOpenAIError(upstreamStatus: number): number {
  if (upstreamStatus === 401 || upstreamStatus === 403 || upstreamStatus === 429) {
    return upstreamStatus
  }
  return 502
}

function isAccountLimitError(error: unknown): boolean {
  return error instanceof HTTPStatusError
    && (error.status === 402 || isAccountUsageLimitMessage(error.message))
}

function disabledResponse(capability: string): Response {
  return json({
    error: `${capability} is temporarily unavailable.`,
    displayMessage: `${capability} is temporarily paused. Please try again later.`,
    code: 'capability_disabled'
  }, 503)
}

async function fetchJSON(url: string, init: RequestInit, source: ErrorSource = 'internal'): Promise<unknown> {
  const response = await fetch(url, init)
  const text = await response.text()
  let data: unknown = null

  if (text) {
    try {
      data = JSON.parse(text)
    } catch {
      data = { message: text }
    }
  }

  if (!response.ok) {
    const message = typeof (data as { error?: { message?: string } } | null)?.error?.message === 'string'
      ? (data as { error: { message: string } }).error.message
      : typeof (data as { message?: string } | null)?.message === 'string'
        ? (data as { message: string }).message
        : `Request failed with status ${response.status}`
    throw new HTTPStatusError(response.status, message, source)
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

async function callDatabaseRPC(
  baseUrl: string,
  bearerToken: string,
  name: string,
  body: Record<string, unknown>,
): Promise<unknown> {
  return await fetchJSON(
    `${baseUrl.replace(/\/$/, '')}/api/database/rpc/${name}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${bearerToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    },
  )
}

async function reserveAgentUsageCost(
  baseUrl: string,
  userToken: string,
  userId: string,
  capability: string,
  estimatedCostUSD: number,
  usageUnits: UsageUnits,
): Promise<string | null> {
  const reservation = await callDatabaseRPC(baseUrl, userToken, 'reserve_agent_usage_cost', {
    p_user_id: userId,
    p_capability: capability,
    p_estimated_cost_usd: estimatedCostUSD,
    p_usage_units: usageUnits,
  }) as UsageReservation

  return Array.isArray(reservation)
    ? reservation[0]?.usage_id ?? null
    : reservation?.usage_id ?? null
}

async function finalizeAgentUsageCost(
  baseUrl: string,
  userToken: string,
  usageId: string | null,
  succeeded: boolean,
  usageUnits?: UsageUnits,
): Promise<void> {
  if (!usageId) {
    return
  }

  const body: Record<string, unknown> = {
    p_usage_id: usageId,
    p_succeeded: succeeded,
  }
  if (usageUnits) {
    body.p_usage_units = usageUnits
  }

  await callDatabaseRPC(baseUrl, userToken, 'finalize_agent_usage_cost', body)
}

function extractResponseText(data: OpenAIResponse): string {
  if (typeof data.output_text === 'string' && data.output_text.trim()) {
    return data.output_text
  }

  return (data.output ?? [])
    .flatMap((item) => item.content ?? [])
    .map((content) => content.text ?? '')
    .filter(Boolean)
    .join('\n')
}

function parseScreenContext(rawText: string): { summary: string; visibleText: string; actionableContext: string } {
  try {
    const parsed = JSON.parse(rawText) as {
      summary?: unknown
      visible_text?: unknown
      actionable_context?: unknown
    }

    return {
      summary: typeof parsed.summary === 'string' ? parsed.summary : rawText,
      visibleText: typeof parsed.visible_text === 'string' ? parsed.visible_text : '',
      actionableContext: typeof parsed.actionable_context === 'string' ? parsed.actionable_context : ''
    }
  } catch {
    return {
      summary: rawText,
      visibleText: '',
      actionableContext: ''
    }
  }
}

export default async function(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  let usageReservationID: string | null = null
  let finalizeBaseUrl: string | null = null
  let finalizeUserToken: string | null = null

  try {
    if (envFlag('VOIYCE_DISABLE_ALL_AI') || envFlag('VOIYCE_DISABLE_SCREEN_CONTEXT')) {
      return disabledResponse('Screen context')
    }

    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const openAIKey = requireEnv('OPENAI_API_KEY')
    finalizeBaseUrl = baseUrl
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null
    finalizeUserToken = userToken
    const user = await getCurrentUser(baseUrl, userToken)

    if (!user?.id) {
      console.warn('[screen-context] Missing or invalid user session.')
      return json({ error: 'Unauthorized' }, 401)
    }

    const body = await req.json() as ScreenContextRequest
    const imageBase64 = body.imageBase64?.trim()

    if (!imageBase64) {
      return json({ error: 'imageBase64 is required.' }, 400)
    }

    const maxImageChars = envNumber('VOIYCE_SCREEN_CONTEXT_MAX_IMAGE_BASE64_CHARS', 8_000_000)
    if (imageBase64.length > maxImageChars) {
      return json({ error: `Screen context image exceeds the ${maxImageChars} character limit.` }, 413)
    }

    if (envFlag('VOIYCE_ENFORCE_AGENT_USAGE_CAPS')) {
      try {
        usageReservationID = await reserveAgentUsageCost(
          baseUrl,
          userToken ?? '',
          user.id,
          'context',
          envNumber('VOIYCE_SCREEN_CONTEXT_ESTIMATED_REQUEST_COST_USD', 0.003),
          {
            request_count: 1,
            screenshot_count: 1,
            image_base64_chars: imageBase64.length,
            prompt_chars: body.prompt?.trim().length ?? 0,
          },
        )
      } catch (error) {
        if (!isAccountLimitError(error)) {
          throw error
        }

        const message = error instanceof Error ? error.message : 'Screen context usage cap reached'
        console.warn('[screen-context] Agent usage reservation failed.', {
          userId: user.id,
          message: redactForLog(message),
        })
        return json({
          error: accountUsageLimitMessage(message),
          code: 'usage_limit_reached',
        }, 402)
      }
    }

    const focusPrompt = body.prompt?.trim()
    const model = Deno.env.get('OPENAI_SCREEN_CONTEXT_MODEL') || 'gpt-4.1-mini'
    const response = await fetchJSON(
      'https://api.openai.com/v1/responses',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${openAIKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model,
          input: [
            {
              role: 'user',
              content: [
                {
                  type: 'input_text',
                  text: [
                    'Analyze this current macOS screen for a voice desktop assistant.',
                    'Return compact JSON with keys: summary, visible_text, actionable_context.',
                    'summary should say what is visible and relevant.',
                    'visible_text should include only important readable text, not every UI label.',
                    'actionable_context should mention likely next actions, targets, fields, or warnings.',
                    focusPrompt ? `User focus: ${focusPrompt}` : ''
                  ].filter(Boolean).join('\n')
                },
                {
                  type: 'input_image',
                  image_url: `data:image/jpeg;base64,${imageBase64}`
                }
              ]
            }
          ]
        })
      },
      'openai',
    ) as OpenAIResponse

    const text = extractResponseText(response).trim()
    if (!text) {
      if (usageReservationID) {
        try {
          await finalizeAgentUsageCost(baseUrl, userToken ?? '', usageReservationID, false)
        } catch (finalizeError) {
          console.warn('[screen-context] Failed to finalize empty-result usage reservation.', finalizeError)
        }
      }
      return json({ error: 'Screen context model returned an empty response.' }, 502)
    }

    try {
      await finalizeAgentUsageCost(baseUrl, userToken ?? '', usageReservationID, true)
    } catch (finalizeError) {
      console.warn('[screen-context] Failed to finalize successful usage reservation.', finalizeError)
    }

    return json(parseScreenContext(text))
  } catch (error) {
    if (usageReservationID && finalizeBaseUrl && finalizeUserToken) {
      try {
        await finalizeAgentUsageCost(finalizeBaseUrl, finalizeUserToken, usageReservationID, false)
      } catch (finalizeError) {
        console.warn('[screen-context] Failed to finalize usage reservation.', finalizeError)
      }
    }

    if (error instanceof HTTPStatusError && error.source === 'internal' && error.status === 401) {
      console.warn('[screen-context] User token rejected.', {
        status: error.status,
        message: redactForLog(error.message)
      })
      return json({ error: 'Unauthorized' }, 401)
    }

    if (error instanceof HTTPStatusError && error.source === 'openai') {
      console.error('[screen-context] OpenAI request failed.', {
        status: error.status,
        message: redactForLog(error.message)
      })
      return json({
        error: AI_SERVICE_UNAVAILABLE_ERROR,
        upstreamStatus: error.status
      }, statusForOpenAIError(error.status))
    }

    console.error('[screen-context] Unhandled failure.', redactForLog(error))
    return json({ error: GENERIC_CLIENT_ERROR }, 500)
  }
}
