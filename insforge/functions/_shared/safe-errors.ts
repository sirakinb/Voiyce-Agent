export const GENERIC_CLIENT_ERROR = 'The request failed. Please try again.'
export const AI_SERVICE_UNAVAILABLE_ERROR = 'The AI service is temporarily unavailable. Please try again.'
export const ACCOUNT_USAGE_LIMIT_ERROR = 'This account has reached its current usage limit. Try again later or contact support if this seems wrong.'

const apiKeyPattern = /sk-(?:proj-)?[A-Za-z0-9_-]{8,}/g
const apiKeyDetectPattern = /sk-(?:proj-)?[A-Za-z0-9_-]{8,}/
const assignmentPattern = /\b(OPENAI_API_KEY|API_KEY|Authorization|x-access-token)\s*[:=]\s*[^'",\s}]+/gi
const bearerPattern = /\bBearer\s+[A-Za-z0-9._-]+/gi
const bearerDetectPattern = /\bBearer\s+[A-Za-z0-9._-]+/i
const sensitiveNamePattern = /\b(OPENAI_API_KEY|API_KEY|Authorization|Bearer|x-access-token)\b/i

export function redactSensitiveString(input: string): string {
  return input
    .replace(bearerPattern, 'Bearer [redacted]')
    .replace(apiKeyPattern, '[redacted-api-key]')
    .replace(assignmentPattern, '$1=[redacted]')
}

export function redactForLog(value: unknown): unknown {
  if (typeof value === 'string') {
    return redactSensitiveString(value)
  }

  if (Array.isArray(value)) {
    return value.map(redactForLog)
  }

  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, nested]) => [
        key,
        sensitiveNamePattern.test(key) ? '[redacted]' : redactForLog(nested),
      ]),
    )
  }

  return value
}

export function safeClientMessage(message: string, fallback = GENERIC_CLIENT_ERROR): string {
  const trimmed = message.trim()
  if (!trimmed || sensitiveNamePattern.test(trimmed) || apiKeyDetectPattern.test(trimmed) || bearerDetectPattern.test(trimmed)) {
    return fallback
  }

  return trimmed.length > 240 ? `${trimmed.slice(0, 237)}...` : trimmed
}

export function isAccountUsageLimitMessage(message: string): boolean {
  const normalized = message.trim().toLowerCase()
  return normalized.includes('usage cap reached')
    || normalized.includes('monthly cap reached')
    || normalized.includes('daily cap reached')
    || normalized.includes('spend cap reached')
    || normalized.includes('usage limit reached')
    || normalized.includes('account limit reached')
}

export function accountUsageLimitMessage(message: string): string {
  const safeMessage = safeClientMessage(message, ACCOUNT_USAGE_LIMIT_ERROR)
  return isAccountUsageLimitMessage(safeMessage) ? safeMessage : ACCOUNT_USAGE_LIMIT_ERROR
}
