import i18n from 'i18next'
import LanguageDetector from 'i18next-browser-languagedetector'
import { initReactI18next } from 'react-i18next'
import es from '../locales/es.json'
import ru from '../locales/ru.json'

// Locale registry: add a JSON file in src/locales and one line here.
export const LOCALES: Record<string, { label: string; resources: typeof es }> = {
  es: { label: 'Español', resources: es },
  ru: { label: 'Русский', resources: ru },
}

export const DEFAULT_LOCALE = 'es'
export const LOCALE_STORAGE_KEY = 'printremeras.locale'

export function supportedLocales() {
  return Object.keys(LOCALES)
}

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: Object.fromEntries(Object.entries(LOCALES).map(([code, { resources }]) => [code, { translation: resources }])),
    fallbackLng: DEFAULT_LOCALE,
    supportedLngs: supportedLocales(),
    load: 'languageOnly',
    nonExplicitSupportedLngs: true,
    interpolation: { escapeValue: false },
    detection: {
      order: ['querystring', 'localStorage', 'navigator'],
      lookupQuerystring: 'locale',
      lookupLocalStorage: LOCALE_STORAGE_KEY,
      caches: ['localStorage'],
    },
    returnNull: false,
  })

export default i18n
