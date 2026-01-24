import { createContext, useContext, useState, useEffect } from 'react'
import { translations } from './translations'

const I18nContext = createContext()

export function I18nProvider({ children }) {
  const [lang, setLang] = useState(() => {
    const params = new URLSearchParams(window.location.search)
    const urlLang = params.get('lang')
    if (urlLang && translations[urlLang]) return urlLang
    const browserLang = navigator.language.slice(0, 2)
    return browserLang === 'ru' ? 'ru' : 'en'
  })

  const t = translations[lang] || translations['en'] || {}

  const switchLang = () => {
    const newLang = lang === 'en' ? 'ru' : 'en'
    setLang(newLang)
    window.history.pushState({}, '', `?lang=${newLang}`)
  }

  useEffect(() => {
    document.documentElement.lang = lang
  }, [lang])

  console.log('I18n lang:', lang, 't keys:', Object.keys(t || {}))
  
  return (
    <I18nContext.Provider value={{ t, lang, switchLang }}>
      {children}
    </I18nContext.Provider>
  )
}

export const useI18n = () => useContext(I18nContext)
