import { memo } from 'react'
import { useI18n } from '../i18n/context'

const flags: Record<string, string> = {
  en: '🇺🇸',
  ru: '🇷🇺'
}

const labels: Record<string, string> = {
  en: 'EN',
  ru: 'RU'
}

export default memo(function LanguageSwitcher() {
  const { lang, switchLang } = useI18n()
  const nextLang = lang === 'en' ? 'ru' : 'en'

  return (
    <button 
      className="lang-switcher" 
      onClick={switchLang}
      aria-label={`Switch to ${nextLang === 'en' ? 'English' : 'Russian'}`}
    >
      <span className="lang-current">
        <span className="lang-flag">{flags[lang]}</span>
        <span className="lang-code">{labels[lang]}</span>
      </span>
      <span className="lang-divider">/</span>
      <span className="lang-next">
        <span className="lang-flag">{flags[nextLang]}</span>
        <span className="lang-code">{labels[nextLang]}</span>
      </span>
    </button>
  )
})
