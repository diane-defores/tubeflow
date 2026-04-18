const DEFAULT_SITE_URL = 'https://tubeflow.winflowz.com'
const DEFAULT_APP_URL = 'https://app.tubeflow.winflowz.com'
const DEFAULT_EMAIL_DOMAIN = 'winflowz.com'

function stripTrailingSlash(url: string): string {
  return url.replace(/\/+$/, '')
}

export const SITE_URL = stripTrailingSlash(
  import.meta.env.PUBLIC_SITE_URL ?? DEFAULT_SITE_URL
)

export const APP_URL = stripTrailingSlash(
  import.meta.env.PUBLIC_APP_URL ?? DEFAULT_APP_URL
)

export const EMAIL_DOMAIN = (
  import.meta.env.PUBLIC_EMAIL_DOMAIN ?? DEFAULT_EMAIL_DOMAIN
).trim()

export function siteUrl(path = '/'): string {
  return new URL(path, `${SITE_URL}/`).toString()
}

export function appUrl(path = '/'): string {
  return new URL(path, `${APP_URL}/`).toString()
}

export function contactEmail(localPart: string): string {
  return `${localPart}@${EMAIL_DOMAIN}`
}
