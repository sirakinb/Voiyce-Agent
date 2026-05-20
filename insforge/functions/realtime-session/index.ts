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

class HTTPStatusError extends Error {
  readonly status: number

  constructor(status: number, message: string) {
    super(message)
    this.name = 'HTTPStatusError'
    this.status = status
  }
}

type AuthUser = {
  id: string
}

type RealtimeSessionRequest = {
  sdp?: string
  model?: string
  mode?: string
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

function disabledResponse(capability: string): Response {
  return json({
    error: `${capability} is temporarily unavailable.`,
    displayMessage: `${capability} is temporarily paused. Please try again later.`,
    code: 'capability_disabled'
  }, 503)
}

async function fetchJSON(url: string, init: RequestInit): Promise<unknown> {
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
    throw new HTTPStatusError(response.status, message)
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
  body: Record<string, unknown>
): Promise<unknown> {
  return await fetchJSON(
    `${baseUrl.replace(/\/$/, '')}/api/database/rpc/${name}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${bearerToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    }
  )
}

async function reserveAgentUsageCost(
  baseUrl: string,
  userToken: string,
  userId: string,
  capability: string,
  estimatedCostUSD: number,
  usageUnits: UsageUnits
): Promise<string | null> {
  const reservation = await callDatabaseRPC(baseUrl, userToken, 'reserve_agent_usage_cost', {
    p_user_id: userId,
    p_capability: capability,
    p_estimated_cost_usd: estimatedCostUSD,
    p_usage_units: usageUnits
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
  usageUnits?: UsageUnits
): Promise<void> {
  if (!usageId) {
    return
  }

  const body: Record<string, unknown> = {
    p_usage_id: usageId,
    p_succeeded: succeeded
  }
  if (usageUnits) {
    body.p_usage_units = usageUnits
  }

  await callDatabaseRPC(baseUrl, userToken, 'finalize_agent_usage_cost', body)
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

export function selectRealtimeModel(requestedModel: string | undefined): string {
  const trimmed = requestedModel?.trim()
  return envFlag('VOIYCE_ALLOW_CLIENT_REALTIME_MODEL') && trimmed
    ? trimmed
    : Deno.env.get('OPENAI_REALTIME_MODEL') || 'gpt-realtime-2'
}

function modeInstructions(mode: string | undefined): string[] {
  switch ((mode ?? '').toLowerCase()) {
    case 'act':
      return [
        'The current user-facing mode is Act. The user expects you to operate apps and websites when asked.',
        'Use native tools first for known actions, then inspect_screen for grounding, then act_with_computer for multi-step visual UI operation.',
        'If an action depends on prior decisions, preferences, project details, or previous-session work, search saved memory first and use only details that directly apply to the action.',
        'Narrate briefly when you are checking the screen or running an action, then report the actual tool result.'
      ]
    case 'talk':
    default:
      return [
        'The current user-facing mode is Talk. Keep the experience conversational, but do not limit yourself to pure chat.',
        'In Talk mode, you should still helpfully take lightweight actions when the user asks: inspect the screen, search session memory, read Gmail or Calendar, check availability, draft content, open apps or URLs, insert text, and switch Voiyce sections.',
        'If the user explicitly asks you to click, type, navigate, or operate something visible, you may use click_screen or another appropriate native tool for simple bounded actions.',
        'Reserve act_with_computer for Act mode or for cases where the user clearly asks for broader computer control. If a Talk request turns into a multi-step UI workflow, explain that Act mode is the stronger mode for that job.'
      ]
  }
}

export function buildRealtimeInstructions(mode: string | undefined): string {
  return [
    'You are Voiyce, a concise voice-first desktop assistant for dictation and computer-work commands.',
    'Speak naturally and briefly, like a capable teammate. Avoid stiff failure language.',
    'For any long-running tool action such as reading the screen, Gmail, Calendar, active-session context, saved memory, or an app action, first say a short progress phrase such as "I am checking that now" or "Give me a second, I am reading the screen."',
    'If a grounding tool is slow, empty, stale, or temporarily fails, do not immediately say you cannot do it. Say what you are checking, retry one appropriate grounding tool when useful, then explain the exact blocker only if it still fails.',
    'The user may ask to read Gmail, send Gmail, read Calendar, check availability, open apps or websites, insert dictated text, click, type, or press keys.',
    'Use native tools when available. Never claim an app was opened, text was inserted, Gmail was read, calendar was checked, or an email was sent unless the tool reports success.',
    'Do not expose internal provider, runtime, tool, or source-label names in normal speech unless the user asks for technical diagnostics.',
    'Do not use Apple Mail or macOS Mail as a fallback. Gmail actions require Google OAuth and the Gmail API.',
    'If a tool says Google is not connected, requires google_oauth, or lacks Screen Recording/Microphone/Accessibility permission, state that exact user-facing blocker and next step. Do not infer account, inbox, calendar, screen, or app access that the tool did not confirm.',
    'Never send email, delete, purchase, submit payments, or perform other irreversible actions unless a confirmation tool/UI explicitly confirms the exact action.',
    'If details are missing for a task, ask one brief follow-up.',
    'If the user asks about booking, scheduling, or availability, call check_calendar with the requested date and time before answering.',
    'If the user asks to switch Voiyce tabs or sections such as Settings, Agent, Agent Log, or Dashboard, call open_voiyce_section instead of visually clicking the UI.',
    'You can inspect the current screen through the native inspect_screen tool. Use it before answering or acting on screen-dependent requests such as "this", "that email", "the visible page", "what I am looking at", drafting replies based on visible content, clicking visible UI, or updating calendar/email from on-screen context.',
    'If the user marks or refers to a highlighted/focused area, use inspect_focus_region. If no focus region exists and the user wants one, call start_focus_highlight and ask them to drag over the area.',
    'Use active-session context for temporal questions about what happened earlier in the current agent session, such as what the user saw a moment ago, what was on screen when they mentioned something, or what they said earlier.',
    'Use saved memory tools before answering questions about previous sessions, recurring projects, user preferences, and remembered work context. Prefer current screen first, active-session context second, and saved memory third unless the user asks about previous work.',
    'When saved memory is used in an answer, cite the date or session in natural language when the tool result includes it, such as "From May 18" or "In the last saved session"; do not recite raw tool fields.',
    'When the user asks you to remember a preference, project detail, or useful fact, call save_long_term_memory with a concise summary.',
    'Prefer inspect_screen for immediate current-screen grounding. Prefer search_session_memory or summarize_session_memory when the request depends on screen or audio history over time. Prefer search_long_term_memory or summarize_long_term_memory when the request depends on prior sessions.',
    'If inspect_screen reports missing Screen Recording permission, explain the exact permission needed and offer request_screen_access.',
    'If a tool returns needsConfirmation with a confirmation_id, ask the user for voice approval in plain language. If they approve, call confirm_pending_action with decision approve. If they decline, call confirm_pending_action with decision cancel. If they ask to stop or end the session, call confirm_pending_action with decision stop_session.',
    'For complex app or website operation in Act mode, call act_with_computer with a concise task. It runs a bounded app-control loop against the current screen and returns when complete or blocked.',
    ...modeInstructions(mode)
  ].join(' ')
}

export function buildRealtimeSession(model: string, mode: string | undefined) {
  return {
    type: 'realtime',
    model,
    instructions: buildRealtimeInstructions(mode),
    audio: {
      input: {
        noise_reduction: {
          type: 'near_field'
        },
        turn_detection: {
          type: 'semantic_vad',
          eagerness: 'low',
          create_response: true,
          interrupt_response: true
        }
      },
      output: {
        voice: 'marin',
        speed: 1.08
      }
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
    if (envFlag('VOIYCE_DISABLE_ALL_AI') || envFlag('VOIYCE_DISABLE_REALTIME')) {
      return disabledResponse('Realtime voice')
    }

    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const openAIKey = requireEnv('OPENAI_API_KEY')
    finalizeBaseUrl = baseUrl
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null
    finalizeUserToken = userToken
    const user = await getCurrentUser(baseUrl, userToken)

    if (!user?.id) {
      console.warn('[realtime-session] Missing or invalid user session.')
      return json({ error: 'Unauthorized' }, 401)
    }

    const body = await req.json() as RealtimeSessionRequest
    const sdp = body.sdp

    if (!sdp || !sdp.trim()) {
      return json({ error: 'sdp is required.' }, 400)
    }

    const maxSDPChars = envNumber('VOIYCE_REALTIME_MAX_SDP_CHARS', 25000)
    if (sdp.length > maxSDPChars) {
      return json({ error: `SDP offer exceeds the ${maxSDPChars} character limit.` }, 413)
    }

    const model = selectRealtimeModel(body.model)
    const estimatedSessionSeconds = Math.round(envNumber('VOIYCE_REALTIME_ESTIMATED_SESSION_SECONDS', 300))

    if (envFlag('VOIYCE_ENFORCE_AGENT_USAGE_CAPS')) {
      try {
        usageReservationID = await reserveAgentUsageCost(
          baseUrl,
          userToken ?? '',
          user.id,
          'realtime',
          envNumber('VOIYCE_REALTIME_ESTIMATED_SESSION_COST_USD', 0.05),
          {
            session_count: 1,
            estimated_session_seconds: estimatedSessionSeconds,
            sdp_chars: sdp.length
          }
        )
      } catch (error) {
        if (!isAccountLimitError(error)) {
          throw error
        }

        const message = error instanceof Error ? error.message : ''
        console.warn('[realtime-session] Agent usage reservation reached an account limit.', {
          userId: user.id,
          message: redactForLog(message)
        })
        return json({
          error: accountUsageLimitMessage(message),
          code: 'usage_limit_reached'
        }, 402)
      }
    }

    const session = buildRealtimeSession(model, body.mode)

    const formData = new FormData()
    formData.set('sdp', sdp)
    formData.set('session', JSON.stringify(session))

    const response = await fetch('https://api.openai.com/v1/realtime/calls', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${openAIKey}`
      },
      body: formData
    })

    const answerSDP = await response.text()

    if (!response.ok) {
      if (usageReservationID) {
        try {
          await finalizeAgentUsageCost(baseUrl, userToken ?? '', usageReservationID, false)
        } catch (finalizeError) {
          console.warn('[realtime-session] Failed to finalize failed usage reservation.', finalizeError)
        }
      }

      console.error('[realtime-session] OpenAI Realtime call failed.', {
        status: response.status,
        body: redactForLog(answerSDP)
      })
      return json({
        error: AI_SERVICE_UNAVAILABLE_ERROR,
        upstreamStatus: response.status
      }, statusForOpenAIError(response.status))
    }

    try {
      await finalizeAgentUsageCost(baseUrl, userToken ?? '', usageReservationID, true)
    } catch (finalizeError) {
      console.warn('[realtime-session] Failed to finalize successful usage reservation.', finalizeError)
    }

    return json({ sdp: answerSDP })
  } catch (error) {
    if (usageReservationID && finalizeBaseUrl && finalizeUserToken) {
      try {
        await finalizeAgentUsageCost(finalizeBaseUrl, finalizeUserToken, usageReservationID, false)
      } catch (finalizeError) {
        console.warn('[realtime-session] Failed to finalize usage reservation.', finalizeError)
      }
    }

    if (error instanceof HTTPStatusError && error.status === 401) {
      console.warn('[realtime-session] User token rejected.', {
        status: error.status,
        message: redactForLog(error.message)
      })
      return json({ error: 'Unauthorized' }, 401)
    }

    console.error('[realtime-session] Unhandled failure.', redactForLog(error))
    return json({ error: GENERIC_CLIENT_ERROR }, 500)
  }
}
