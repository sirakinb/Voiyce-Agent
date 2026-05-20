import {
  accountUsageLimitMessage,
  AI_SERVICE_UNAVAILABLE_ERROR,
  GENERIC_CLIENT_ERROR,
  isAccountUsageLimitMessage,
  redactForLog,
  safeClientMessage,
} from '../_shared/safe-errors.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
}

type ErrorSource = 'client' | 'internal' | 'openai'

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

class ClientRequestError extends HTTPStatusError {
  constructor(status: number, message: string) {
    super(status, message, 'client')
  }
}

type AuthUser = {
  id: string
}

type ComputerUseStepRequest = {
  task?: string
  previousResponseId?: string
  callId?: string
  screenshotBase64?: string
  width?: number
  height?: number
  safetyMode?: string
  acknowledgedSafetyChecks?: string[]
}

type OpenAIOutputItem = {
  id?: string
  type?: string
  call_id?: string
  action?: Record<string, unknown>
  actions?: Array<Record<string, unknown>>
  pending_safety_checks?: Array<{ id?: string, code?: string, message?: string }>
  content?: Array<{ type?: string, text?: string }>
}

type OpenAIResponse = {
  id?: string
  output_text?: string
  output?: OpenAIOutputItem[]
}

type UsageReservation = Array<{ usage_id?: string }> | { usage_id?: string } | null
type UsageUnits = Record<string, number | string | boolean>

const prohibitedComputerUsePatterns: Array<{ label: string, pattern: RegExp }> = [
  {
    label: 'credential theft',
    pattern: /\b(steal|exfiltrate|extract|dump|reveal|show|copy|get|find)\b.{0,80}\b(password|passcode|credential|api key|token|secret|ssh key|keychain|1password|lastpass|bitwarden)\b/i,
  },
  {
    label: 'catastrophic deletion',
    pattern: /\b(rm\s+-rf|erase disk|format (the )?(disk|drive)|wipe (the )?(computer|mac|disk|drive)|factory reset|delete all (files|data)|delete system|remove everything)\b/i,
  },
  {
    label: 'fraud',
    pattern: /\b(fraud|stolen card|fake refund|chargeback fraud|launder|phish|scam|impersonate)\b/i,
  },
  {
    label: 'illegal access',
    pattern: /\b(bypass|hack|break into|take over|unauthorized access|crack)\b.{0,80}\b(login|account|password|paywall|2fa|mfa|computer|system)\b/i,
  },
  {
    label: 'hidden action',
    pattern: /\b(hide|conceal|cover up|without (me|them|the user) (seeing|noticing|knowing)|silently)\b.{0,80}\b(click|send|submit|delete|purchase|post|change|transfer)\b/i,
  },
]

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

function computerUseReservationUnits(body: ComputerUseStepRequest): UsageUnits {
  return {
    step_count: 1,
    screenshot_count: body.screenshotBase64?.trim() ? 1 : 0,
    screenshot_base64_chars: body.screenshotBase64?.length ?? 0,
    task_chars: body.task?.trim().length ?? 0,
    acknowledged_safety_check_count: body.acknowledgedSafetyChecks?.length ?? 0,
    continuation_count: body.previousResponseId || body.callId ? 1 : 0,
  }
}

function computerUseFinalUnits(data: OpenAIResponse): UsageUnits {
  const output = data.output ?? []
  const outputActionCount = output.reduce((count, item) => {
    return count
      + (item.action ? 1 : 0)
      + (Array.isArray(item.actions) ? item.actions.length : 0)
  }, 0)
  const pendingSafetyCheckCount = output.reduce((count, item) => {
    return count + (item.pending_safety_checks?.length ?? 0)
  }, 0)

  return {
    output_item_count: output.length,
    output_action_count: outputActionCount,
    pending_safety_check_count: pendingSafetyCheckCount,
  }
}

function responseText(data: OpenAIResponse): string {
  if (typeof data.output_text === 'string' && data.output_text.trim()) {
    return data.output_text
  }

  return (data.output ?? [])
    .flatMap((item) => item.content ?? [])
    .map((content) => content.text ?? '')
    .filter(Boolean)
    .join('\n')
}

function outputComputerCalls(data: OpenAIResponse) {
  return (data.output ?? [])
    .filter((item) => item.type === 'computer_call')
    .map((item) => ({
      callId: item.call_id ?? item.id ?? '',
      actions: item.actions ?? (item.action ? [item.action] : []),
      pendingSafetyChecks: item.pending_safety_checks ?? []
    }))
    .filter((item) => item.callId)
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

export function computerTool() {
  return { type: 'computer' }
}

export function instructions(safetyMode: string | undefined): string {
  return [
    'You are controlling the user\'s macOS computer for Voiyce Act mode.',
    'Use the computer tool for visible UI interactions only.',
    'Prefer a small number of precise actions. Stop when the requested task is complete or you need the user.',
    'Do not delete files, send messages, purchase, submit payments, change account settings, or perform irreversible actions.',
    'Do not request or reveal credentials, bypass access controls, conceal actions from the user, commit fraud, evade platform policies, or assist illegal access.',
    'If the task asks for credential theft, catastrophic deletion, fraud, illegal access, or hidden actions, refuse and stop.',
    safetyMode === 'unrestricted'
      ? 'The user selected Unrestricted mode, but full system deletion and prohibited actions are still disallowed.'
      : 'Ask the user for confirmation before sensitive or irreversible actions.'
  ].join(' ')
}

export function prohibitedComputerUseReason(task: string | undefined): string | null {
  const trimmed = task?.trim()
  if (!trimmed) {
    return null
  }

  return prohibitedComputerUsePatterns.find((entry) => entry.pattern.test(trimmed))?.label ?? null
}

export function buildOpenAIRequestPayload(body: ComputerUseStepRequest, model: string) {
  let input: unknown
  if (body.previousResponseId && body.callId && body.screenshotBase64) {
    input = [
      {
        type: 'computer_call_output',
        call_id: body.callId,
        output: {
          type: 'computer_screenshot',
          image_url: `data:image/png;base64,${body.screenshotBase64}`,
          detail: 'original'
        }
      }
    ]
  } else {
    const task = body.task?.trim()
    if (!task) {
      throw new ClientRequestError(400, 'task is required for the first computer-use step.')
    }

    input = `${task} Use the computer tool for UI interaction.`
  }

  return {
    model,
    previous_response_id: body.previousResponseId || undefined,
    instructions: instructions(body.safetyMode),
    tools: [computerTool()],
    input,
    reasoning: { summary: 'concise' }
  }
}

export function validateComputerUseRequest(body: ComputerUseStepRequest): void {
  const maxTaskChars = envNumber('VOIYCE_COMPUTER_USE_MAX_TASK_CHARS', 2000)
  const maxScreenshotChars = envNumber('VOIYCE_COMPUTER_USE_MAX_SCREENSHOT_BASE64_CHARS', 8_000_000)
  const task = body.task?.trim()

  if (task && task.length > maxTaskChars) {
    throw new ClientRequestError(413, `Computer Use task exceeds the ${maxTaskChars} character limit.`)
  }

  const prohibitedReason = prohibitedComputerUseReason(task)
  if (prohibitedReason) {
    throw new ClientRequestError(403, `Computer Use cannot help with ${prohibitedReason}.`)
  }

  if (body.screenshotBase64 && body.screenshotBase64.length > maxScreenshotChars) {
    throw new ClientRequestError(413, `Computer Use screenshot exceeds the ${maxScreenshotChars} character limit.`)
  }

  if (body.acknowledgedSafetyChecks && body.acknowledgedSafetyChecks.length > 20) {
    throw new ClientRequestError(400, 'Too many acknowledged safety checks.')
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
    if (envFlag('VOIYCE_DISABLE_ALL_AI') || envFlag('VOIYCE_DISABLE_COMPUTER_USE')) {
      return disabledResponse('Computer Use')
    }

    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const openAIKey = requireEnv('OPENAI_API_KEY')
    finalizeBaseUrl = baseUrl
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null
    finalizeUserToken = userToken
    const user = await getCurrentUser(baseUrl, userToken)

    if (!user?.id) {
      console.warn('[computer-use-step] Missing or invalid user session.')
      return json({ error: 'Unauthorized' }, 401)
    }

    const body = await req.json() as ComputerUseStepRequest
    validateComputerUseRequest(body)
    const model = Deno.env.get('OPENAI_COMPUTER_USE_MODEL') || 'gpt-5.5'
    const reservationUnits = computerUseReservationUnits(body)

    if (envFlag('VOIYCE_ENFORCE_AGENT_USAGE_CAPS')) {
      try {
        usageReservationID = await reserveAgentUsageCost(
          baseUrl,
          userToken ?? '',
          user.id,
          'computer_use',
          envNumber('VOIYCE_COMPUTER_USE_ESTIMATED_STEP_COST_USD', 0.02),
          reservationUnits,
        )
      } catch (error) {
        if (!isAccountLimitError(error)) {
          throw error
        }

        const message = error instanceof Error ? error.message : ''
        console.warn('[computer-use-step] Agent usage reservation reached an account limit.', {
          userId: user.id,
          message: redactForLog(message),
        })
        return json({
          error: accountUsageLimitMessage(message),
          code: 'usage_limit_reached'
        }, 402)
      }
    }

    const responsePayload = buildOpenAIRequestPayload(body, model)

    const response = await fetchJSON(
      'https://api.openai.com/v1/responses',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${openAIKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(responsePayload)
      },
      'openai',
    ) as OpenAIResponse

    try {
      await finalizeAgentUsageCost(baseUrl, userToken ?? '', usageReservationID, true, computerUseFinalUnits(response))
    } catch (finalizeError) {
      console.warn('[computer-use-step] Failed to finalize successful usage reservation.', finalizeError)
    }

    return json({
      responseId: response.id,
      message: responseText(response),
      computerCalls: outputComputerCalls(response)
    })
  } catch (error) {
    if (usageReservationID && finalizeBaseUrl && finalizeUserToken) {
      try {
        await finalizeAgentUsageCost(finalizeBaseUrl, finalizeUserToken, usageReservationID, false)
      } catch (finalizeError) {
        console.warn('[computer-use-step] Failed to finalize usage reservation.', finalizeError)
      }
    }

    if (error instanceof ClientRequestError) {
      return json({ error: safeClientMessage(error.message) }, error.status)
    }

    if (error instanceof HTTPStatusError && error.source === 'internal' && error.status === 401) {
      console.warn('[computer-use-step] User token rejected.', {
        status: error.status,
        message: redactForLog(error.message)
      })
      return json({ error: 'Unauthorized' }, 401)
    }

    if (error instanceof HTTPStatusError && error.source === 'openai') {
      console.error('[computer-use-step] OpenAI request failed.', {
        status: error.status,
        message: redactForLog(error.message)
      })
      return json({
        error: AI_SERVICE_UNAVAILABLE_ERROR,
        upstreamStatus: error.status
      }, statusForOpenAIError(error.status))
    }

    console.error('[computer-use-step] Unhandled failure.', redactForLog(error))
    return json({ error: GENERIC_CLIENT_ERROR }, 500)
  }
}
