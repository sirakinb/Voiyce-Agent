const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
}

class HTTPStatusError extends Error {
  readonly status: number
  readonly payload: unknown

  constructor(status: number, message: string, payload: unknown = null) {
    super(message)
    this.name = 'HTTPStatusError'
    this.status = status
    this.payload = payload
  }
}

type AuthUser = {
  id: string
}

type VideoDBRequest = {
  action?: string
  sessionID?: string
  displayStreamID?: string
  micStreamID?: string
  sceneIndexID?: string
  query?: string
}

type VideoDBResponse = {
  ok: boolean
  sessionID?: string
  clientToken?: string
  displayStreamID?: string
  micStreamID?: string
  sceneIndexID?: string
  summary?: string
  data?: Record<string, string>
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

function videoDBKey(): string {
  const value = Deno.env.get('VIDEO_DB_API_KEY') ?? Deno.env.get('VIDEODB_API_KEY')
  if (!value) {
    throw new Error('Missing required environment variable: VIDEO_DB_API_KEY')
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
      : typeof (data as { error?: string } | null)?.error === 'string'
        ? (data as { error: string }).error
        : typeof (data as { message?: string } | null)?.message === 'string'
          ? (data as { message: string }).message
          : `Request failed with status ${response.status}`
    throw new HTTPStatusError(response.status, message, data)
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

function authHeaders(apiKey: string): HeadersInit {
  return {
    'Content-Type': 'application/json',
    'x-access-token': apiKey
  }
}

function dataObject<T>(payload: unknown): T {
  const wrapped = payload as { data?: T } | null
  return (wrapped?.data ?? payload) as T
}

async function createSession(user: AuthUser, apiKey: string, baseUrl: string): Promise<VideoDBResponse> {
  const session = await fetchJSON('https://api.videodb.io/collection/default/capture/session', {
    method: 'POST',
    headers: authHeaders(apiKey),
    body: JSON.stringify({
      end_user_id: user.id,
      callback_url: `${baseUrl.replace(/\/$/, '')}/functions/videodb-session`,
      metadata: {
        app: 'voiyce-agent',
        mode: 'realtime-agent-memory'
      }
    })
  })

  const token = await fetchJSON('https://api.videodb.io/capture/session/token', {
    method: 'POST',
    headers: authHeaders(apiKey),
    body: JSON.stringify({
      user_id: user.id,
      expires_in: 86400
    })
  })

  const sessionData = dataObject<{ session_id?: string; id?: string }>(session)
  const tokenData = dataObject<{ token?: string }>(token)
  const sessionID = sessionData.session_id ?? sessionData.id

  if (!sessionID || !tokenData.token) {
    throw new Error('VideoDB did not return a capture session and client token.')
  }

  return {
    ok: true,
    sessionID,
    clientToken: tokenData.token,
    summary: 'VideoDB capture session created.'
  }
}

async function stopSession(request: VideoDBRequest, apiKey: string): Promise<VideoDBResponse> {
  if (!request.sessionID) {
    return { ok: false, summary: 'No VideoDB session was active.' }
  }

  await fetchJSON('https://api.videodb.io/capture/session/stop', {
    method: 'POST',
    headers: authHeaders(apiKey),
    body: JSON.stringify({ session_id: request.sessionID })
  })

  return { ok: true, sessionID: request.sessionID, summary: 'VideoDB capture session stopped.' }
}

async function startSceneIndex(request: VideoDBRequest, apiKey: string): Promise<VideoDBResponse> {
  if (!request.displayStreamID) {
    throw new Error('displayStreamID is required.')
  }

  const payload = await fetchJSON(`https://api.videodb.io/rtstream/${request.displayStreamID}/index/scene`, {
    method: 'POST',
    headers: authHeaders(apiKey),
    body: JSON.stringify({
      extraction_type: 'time',
      extraction_config: {
        time: 5,
        frame_count: 2
      },
      prompt: 'Describe the user-visible desktop context, important readable text, active app or web page, and actionable UI state for a voice agent.',
      model_name: 'GPT4o',
      model_config: {},
      name: 'Voiyce Agent Screen Memory'
    })
  })

  const data = dataObject<{ rtstream_index_id?: string; scene_index_id?: string; id?: string }>(payload)
  const sceneIndexID = data.rtstream_index_id ?? data.scene_index_id ?? data.id

  return {
    ok: true,
    displayStreamID: request.displayStreamID,
    sceneIndexID,
    summary: 'VideoDB screen scene index started.'
  }
}

async function startTranscription(request: VideoDBRequest, apiKey: string): Promise<VideoDBResponse> {
  if (!request.micStreamID) {
    throw new Error('micStreamID is required.')
  }

  await fetchJSON(`https://api.videodb.io/rtstream/${request.micStreamID}/transcription/`, {
    method: 'POST',
    headers: authHeaders(apiKey),
    body: JSON.stringify({
      action: 'start',
      engine: 'default'
    })
  })

  return {
    ok: true,
    micStreamID: request.micStreamID,
    summary: 'VideoDB microphone transcription started.'
  }
}

async function searchMemory(request: VideoDBRequest, apiKey: string): Promise<VideoDBResponse> {
  if (!request.displayStreamID || !request.sceneIndexID || !request.query) {
    throw new Error('displayStreamID, sceneIndexID, and query are required.')
  }

  const payload = await fetchJSON(`https://api.videodb.io/rtstream/${request.displayStreamID}/search`, {
    method: 'POST',
    headers: authHeaders(apiKey),
    body: JSON.stringify({
      query: request.query,
      scene_index_id: request.sceneIndexID,
      result_threshold: 5,
      score_threshold: 0.35,
      stitch: true,
      rerank: false
    })
  })

  const results = ((payload as { data?: { results?: Array<{ start?: number; end?: number; text?: string; score?: number }> } }).data?.results ?? [])
  const summary = results.length
    ? results.map((result) => {
      const time = [result.start, result.end].filter((value) => value !== undefined).join('-')
      return `${time}: ${result.text ?? 'matching scene'}${result.score !== undefined ? ` (${result.score.toFixed(2)})` : ''}`
    }).join('\n')
    : 'No matching VideoDB screen-memory results yet.'

  return {
    ok: true,
    displayStreamID: request.displayStreamID,
    sceneIndexID: request.sceneIndexID,
    summary,
    data: {
      result_count: String(results.length),
      results_json: JSON.stringify(results.slice(0, 5))
    }
  }
}

async function summarizeMemory(request: VideoDBRequest, apiKey: string): Promise<VideoDBResponse> {
  const scenes = request.displayStreamID && request.sceneIndexID
    ? await fetchJSON(`https://api.videodb.io/rtstream/${request.displayStreamID}/index/scene/${request.sceneIndexID}?page_size=20`, {
      method: 'GET',
      headers: { 'x-access-token': apiKey }
    }).catch(() => null)
    : null
  const transcript = request.micStreamID
    ? await fetchJSON(`https://api.videodb.io/rtstream/${request.micStreamID}/transcription/?page_size=20`, {
      method: 'GET',
      headers: { 'x-access-token': apiKey }
    }).catch(() => null)
    : null

  const sceneRecords = ((scenes as { data?: { scene_index_records?: Array<{ start?: number; end?: number; description?: string }> } } | null)?.data?.scene_index_records ?? [])
  const transcriptRecords = ((transcript as { data?: { transcription_records?: Array<{ start?: number; end?: number; text?: string }> } } | null)?.data?.transcription_records ?? [])

  const screenSummary = sceneRecords.slice(-8).map((record) => {
    const time = [record.start, record.end].filter((value) => value !== undefined).join('-')
    return `${time}: ${record.description ?? ''}`.trim()
  }).filter(Boolean).join('\n')
  const voiceSummary = transcriptRecords.slice(-8).map((record) => {
    const time = [record.start, record.end].filter((value) => value !== undefined).join('-')
    return `${time}: ${record.text ?? ''}`.trim()
  }).filter(Boolean).join('\n')

  return {
    ok: true,
    displayStreamID: request.displayStreamID,
    micStreamID: request.micStreamID,
    sceneIndexID: request.sceneIndexID,
    summary: [
      screenSummary ? `Screen memory:\n${screenSummary}` : '',
      voiceSummary ? `Voice memory:\n${voiceSummary}` : ''
    ].filter(Boolean).join('\n\n') || 'VideoDB memory is running, but indexed context is not available yet.',
    data: {
      scene_count: String(sceneRecords.length),
      transcript_count: String(transcriptRecords.length)
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

  try {
    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null
    const user = await getCurrentUser(baseUrl, userToken)

    if (!user?.id) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const apiKey = videoDBKey()
    const request = await req.json() as VideoDBRequest

    switch (request.action) {
      case 'create':
        return json(await createSession(user, apiKey, baseUrl))
      case 'stop':
        return json(await stopSession(request, apiKey))
      case 'start_scene_index':
        return json(await startSceneIndex(request, apiKey))
      case 'start_transcription':
        return json(await startTranscription(request, apiKey))
      case 'search':
        return json(await searchMemory(request, apiKey))
      case 'summary':
        return json(await summarizeMemory(request, apiKey))
      default:
        return json({ error: 'Unknown action.' }, 400)
    }
  } catch (error) {
    if (error instanceof HTTPStatusError) {
      return json({ error: error.message, upstreamStatus: error.status }, error.status === 401 ? 502 : 500)
    }

    return json({ error: error instanceof Error ? error.message : 'Unknown error' }, 500)
  }
}
