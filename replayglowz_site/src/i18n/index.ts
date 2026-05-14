import en from './en'
import fr from './fr'

const translations = { en, fr } as const

export type Locale = keyof typeof translations
export type Translations = typeof en

export function getTranslations(locale: string = 'en'): Translations {
  return translations[locale as Locale] ?? translations.en
}

export function getLocaleFromUrl(url: URL): Locale {
  const [, locale] = url.pathname.split('/')
  if (locale === 'fr') return 'fr'
  return 'en'
}

export function localizeHref(href: string, locale: Locale): string {
  if (locale === 'en') return href
  if (href.startsWith('http')) return href
  return `/fr${href === '/' ? '' : href}`
}
