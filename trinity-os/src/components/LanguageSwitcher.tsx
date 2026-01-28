import { memo, useState } from 'react'
import { useI18n } from '../i18n/context'

const flags: Record<string, string> = {
  en: '🇺🇸',
  ru: '🇷🇺',
  de: '🇩🇪',
  zh: '🇨🇳',
  es: '🇪🇸'
}

const labels: Record<string, string> = {
  en: 'EN',
  ru: 'RU',
  de: 'DE',
  zh: '中文',
  es: 'ES'
}

const LANGS = ['en', 'ru', 'de', 'zh', 'es']

export default memo(function LanguageSwitcher() {
  const { lang, setLang } = useI18n()
  const [open, setOpen] = useState(false)
  
  const handleLangChange = (newLang: string) => {
    setLang(newLang)
    setOpen(false)
    
    // Update URL query param with new language
    const url = new URL(window.location.href)
    url.searchParams.set('lang', newLang)
    window.history.replaceState({}, '', url.toString())
  }

  return (
    <div className="lang-switcher-wrap">
      <button 
        className="lang-switcher" 
        onClick={() => setOpen(!open)}
        aria-label="Select language"
      >
        <span className="lang-flag">{flags[lang] || '🌐'}</span>
        <span className="lang-code">{labels[lang] || lang}</span>
        <span className="lang-arrow">{open ? '▲' : '▼'}</span>
      </button>
      
      {open && (
        <div className="lang-dropdown">
          {LANGS.filter(l => l !== lang).map(l => (
            <button 
              key={l} 
              className="lang-option"
              onClick={() => handleLangChange(l)}
            >
              <span className="lang-flag">{flags[l]}</span>
              <span className="lang-code">{labels[l]}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
})
