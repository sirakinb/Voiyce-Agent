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

  try {
    const baseUrl = requireEnv('INSFORGE_BASE_URL')
    const openAIKey = requireEnv('OPENAI_API_KEY')
    const authHeader = req.headers.get('Authorization')
    const userToken = authHeader ? authHeader.replace('Bearer ', '') : null
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

    const focusPrompt = body.prompt?.trim()
    const model = Deno.env.get('OPENAI_SCREEN_CONTEXT_MODEL') || 'gpt-4.1-mini'
    const response = await fetchJSON('https://api.openai.com/v1/responses', {
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
    }) as OpenAIResponse

    const text = extractResponseText(response).trim()
    if (!text) {
      return json({ error: 'Screen context model returned an empty response.' }, 502)
    }

    return json(parseScreenContext(text))
  } catch (error) {
    if (error instanceof HTTPStatusError && error.status === 401) {
      console.warn('[screen-context] User token rejected.', {
        status: error.status,
        message: error.message
      })
      return json({ error: 'Unauthorized' }, 401)
    }

    console.error('[screen-context] Unhandled failure.', error)
    return json({ error: error instanceof Error ? error.message : 'Unknown error' }, 500)
  }
}
