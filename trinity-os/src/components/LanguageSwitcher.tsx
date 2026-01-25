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

export default memo(function LanguageSwitcher() {
  const { lang, setLang, availableLangs } = useI18n()
  const [open, setOpen] = useState(false)

  return (
    <div className="lang-switcher-wrap">
      <button 
        className="lang-switcher" 
        onClick={() => setOpen(!open)}
        aria-label="Select language"
      >
        <span className="lang-flag">{flags[lang]}</span>
        <span className="lang-code">{labels[lang]}</span>
        <span className="lang-arrow">{open ? '▲' : '▼'}</span>
      </button>
      
      {open && (
        <div className="lang-dropdown">
          {availableLangs.filter(l => l !== lang).map(l => (
            <button 
              key={l} 
              className="lang-option"
              onClick={() => { setLang(l); setOpen(false); }}
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
