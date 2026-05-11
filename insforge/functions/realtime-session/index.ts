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

function extractOpenAIErrorMessage(payload: string, fallbackStatus: number): string {
  if (!payload) {
    return `OpenAI Realtime request failed with status ${fallbackStatus}`
  }

  try {
    const parsed = JSON.parse(payload) as { error?: { message?: string }, message?: string }
    return parsed.error?.message ?? parsed.message ?? `OpenAI Realtime request failed with status ${fallbackStatus}`
  } catch {
    return payload
  }
}

export default async function(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  try {
    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const openAIKey = requireEnv('OPENAI_API_KEY')
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null
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

    const model = body.model?.trim() || Deno.env.get('OPENAI_REALTIME_MODEL') || 'gpt-realtime-2'
    const session = {
      type: 'realtime',
      model,
      instructions: [
        'You are Voiyce, a concise voice-first desktop assistant for dictation and computer-work commands.',
        'The user may ask to read Gmail, send Gmail, read Calendar, check availability, open apps or websites, insert dictated text, click, type, or press keys.',
        'Use native tools when available. Never claim an app was opened, text was inserted, Gmail was read, calendar was checked, or an email was sent unless the tool reports success.',
        'Do not use Apple Mail or macOS Mail as a fallback. Gmail actions require Google OAuth and the Gmail API.',
        'Never send email, delete, purchase, submit payments, or perform other irreversible actions unless a confirmation tool/UI explicitly confirms the exact action.',
        'If details are missing for a task, ask one brief follow-up.',
        'If the user asks about booking, scheduling, or availability, call check_calendar with the requested date and time before answering.'
      ].join(' '),
      audio: {
        output: {
          voice: 'marin'
        }
      }
    }

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
      console.error('[realtime-session] OpenAI Realtime call failed.', {
        status: response.status,
        body: answerSDP
      })
      return json({
        error: extractOpenAIErrorMessage(answerSDP, response.status),
        upstreamStatus: response.status,
        upstreamBody: answerSDP
      }, 502)
    }

    return json({ sdp: answerSDP })
  } catch (error) {
    if (error instanceof HTTPStatusError && error.status === 401) {
      console.warn('[realtime-session] User token rejected.', {
        status: error.status,
        message: error.message
      })
      return json({ error: 'Unauthorized' }, 401)
    }

    console.error('[realtime-session] Unhandled failure.', error)
    return json({ error: error instanceof Error ? error.message : 'Unknown error' }, 500)
  }
}
