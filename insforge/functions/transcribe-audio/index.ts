const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
}

const MAX_AUDIO_BYTES = 10 * 1024 * 1024

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

type BillingProfile = {
  user_id: string
  subscription_status?: string | null
  beta_unlocked_at?: string | null
}

type TranscriptionRequest = {
  audioBase64?: string
  fileName?: string
  mimeType?: string
  language?: string
  model?: string
  durationSeconds?: number
}

type OpenAITranscriptionResponse = {
  text?: string
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

function isSubscriptionActive(status: string | null | undefined): boolean {
  return ['active', 'trialing', 'past_due'].includes(status ?? '')
}

function estimateTranscriptionCostUSD(durationSeconds: number | undefined): number {
  const seconds = Number.isFinite(durationSeconds) && durationSeconds && durationSeconds > 0
    ? durationSeconds
    : 60
  const centsPerMinute = Number(Deno.env.get('OPENAI_TRANSCRIPTION_COST_CENTS_PER_MINUTE') ?? '0.6')
  const cost = (seconds / 60) * (centsPerMinute / 100)
  return Math.max(Math.ceil(cost * 1000000) / 1000000, 0.000001)
}

function decodeBase64ToBytes(input: string): Uint8Array {
  const normalized = input.includes(',')
    ? input.slice(input.indexOf(',') + 1)
    : input
  const binary = atob(normalized)
  const bytes = new Uint8Array(binary.length)

  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index)
  }

  return bytes
}

function extractOpenAIErrorMessage(payload: unknown, fallbackStatus: number): string {
  if (typeof (payload as { error?: { message?: string } } | null)?.error?.message === 'string') {
    return (payload as { error: { message: string } }).error.message
  }

  if (typeof (payload as { message?: string } | null)?.message === 'string') {
    return (payload as { message: string }).message
  }

  return `OpenAI transcription request failed with status ${fallbackStatus}`
}

export default async function(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  let betaUsageID: string | null = null
  let finalizeBaseUrl: string | null = null
  let finalizeUserToken: string | null = null

  try {
    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const apiKey = requireEnv('API_KEY')
    const openAIKey = requireEnv('OPENAI_API_KEY')
    finalizeBaseUrl = baseUrl
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null
    finalizeUserToken = userToken

    const user = await getCurrentUser(baseUrl, userToken)
    if (!user?.id) {
      console.warn('[transcribe-audio] Missing or invalid user session.')
      return json({ error: 'Unauthorized' }, 401)
    }

    const body = await req.json() as TranscriptionRequest
    const audioBase64 = body.audioBase64?.trim()

    if (!audioBase64) {
      return json({ error: 'audioBase64 is required.' }, 400)
    }

    const audioBytes = decodeBase64ToBytes(audioBase64)
    if (audioBytes.byteLength == 0) {
      return json({ error: 'Audio payload was empty.' }, 400)
    }

    if (audioBytes.byteLength > MAX_AUDIO_BYTES) {
      return json({ error: `Audio payload exceeds the ${MAX_AUDIO_BYTES / (1024 * 1024)}MB limit.` }, 413)
    }

    const fileName = body.fileName?.trim() || 'recording.wav'
    const mimeType = body.mimeType?.trim() || 'audio/wav'
    const model = body.model?.trim() || Deno.env.get('OPENAI_TRANSCRIPTION_MODEL') || 'whisper-1'
    const language = body.language?.trim() || 'en'
    const profile = await findBillingProfile(baseUrl, apiKey, user.id)
    const shouldReserveBetaSpend = Boolean(profile?.beta_unlocked_at)
      && !isSubscriptionActive(profile?.subscription_status)

    if (shouldReserveBetaSpend) {
      try {
        const reservation = await callDatabaseRPC(baseUrl, userToken ?? '', 'reserve_beta_transcription_cost', {
          p_user_id: user.id,
          p_estimated_cost_usd: estimateTranscriptionCostUSD(body.durationSeconds)
        }) as Array<{ usage_id?: string }> | { usage_id?: string } | null
        betaUsageID = Array.isArray(reservation)
          ? reservation[0]?.usage_id ?? null
          : reservation?.usage_id ?? null
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Beta monthly transcription cap reached'
        console.warn('[transcribe-audio] Beta reservation failed.', { userId: user.id, message })
        return json({ error: message }, 402)
      }
    }

    const formData = new FormData()
    const audioBuffer = audioBytes.buffer.slice(
      audioBytes.byteOffset,
      audioBytes.byteOffset + audioBytes.byteLength
    ) as ArrayBuffer
    formData.set('model', model)
    formData.set('response_format', 'json')
    formData.set('language', language)
    formData.set('file', new Blob([audioBuffer], { type: mimeType }), fileName)

    const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${openAIKey}`
      },
      body: formData
    })

    const responseText = await response.text()
    const payload = responseText ? JSON.parse(responseText) : null

    if (!response.ok) {
      if (betaUsageID) {
        await callDatabaseRPC(baseUrl, userToken ?? '', 'finalize_beta_transcription_cost', {
          p_usage_id: betaUsageID,
          p_succeeded: false
        })
      }

      console.error('[transcribe-audio] OpenAI transcription failed.', {
        status: response.status,
        payload
      })
      return json({ error: extractOpenAIErrorMessage(payload, response.status) }, 502)
    }

    const transcription = payload as OpenAITranscriptionResponse | null
    const text = transcription?.text?.trim()

    if (!text) {
      if (betaUsageID) {
        await callDatabaseRPC(baseUrl, userToken ?? '', 'finalize_beta_transcription_cost', {
          p_usage_id: betaUsageID,
          p_succeeded: false
        })
      }

      return json({ error: 'OpenAI returned an empty transcription.' }, 502)
    }

    if (betaUsageID) {
      await callDatabaseRPC(baseUrl, userToken ?? '', 'finalize_beta_transcription_cost', {
        p_usage_id: betaUsageID,
        p_succeeded: true
      })
    }

    return json({ text })
  } catch (error) {
    if (betaUsageID && finalizeBaseUrl && finalizeUserToken) {
      await callDatabaseRPC(finalizeBaseUrl, finalizeUserToken, 'finalize_beta_transcription_cost', {
        p_usage_id: betaUsageID,
        p_succeeded: false
      })
    }

    if (error instanceof HTTPStatusError && error.status === 401) {
      console.warn('[transcribe-audio] User token rejected.', {
        status: error.status,
        message: error.message
      })
      return json({ error: 'Unauthorized' }, 401)
    }

    console.error('[transcribe-audio] Unhandled failure.', error)
    return json({ error: error instanceof Error ? error.message : 'Unknown error' }, 500)
  }
}
