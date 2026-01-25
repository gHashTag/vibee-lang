import { useState, useEffect } from 'react'
import { useI18n } from '../i18n/context'

const sectionIds = ['hero', 'problem', 'solution', 'whynow', 'calculator', 'traction', 'market', 'gtm', 'competition', 'roadmap', 'team', 'ecosystem', 'invest']

export default function Navigation() {
  const { t, switchLang } = useI18n()
  const [active, setActive] = useState('hero')

  useEffect(() => {
    const handleScroll = () => {
      const scrollY = window.scrollY
      for (const id of sectionIds) {
        const el = document.getElementById(id)
        if (el && scrollY >= (el as HTMLElement).offsetTop - 200) {
          setActive(id)
        }
      }
    }
    window.addEventListener('scroll', handleScroll)
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  const scrollTo = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <nav>
      {t.nav?.map((item: string, i: number) => (
        <a
          key={i}
          href={`#${sectionIds[i]}`}
          className={active === sectionIds[i] ? 'active' : ''}
          onClick={(e) => { e.preventDefault(); scrollTo(sectionIds[i]) }}
        >
          {item}
        </a>
      ))}
      <div className="lang-toggle" onClick={switchLang}>
        {t.langSwitch}
      </div>
    </nav>
  )
}
