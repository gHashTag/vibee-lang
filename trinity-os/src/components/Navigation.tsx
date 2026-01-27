import { useState, useEffect, memo } from 'react'
import { useI18n } from '../i18n/context'
import { Link } from 'react-router-dom'
import LanguageSwitcher from './LanguageSwitcher'

const sectionIds = ['hero', 'problem', 'solution', 'whynow', 'calculator', 'traction', 'market', 'gtm', 'competition', 'roadmap', 'team', 'ecosystem', 'invest']

export default memo(function Navigation() {
  const { t } = useI18n()
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
      <Link 
        to="/quantum" 
        style={{ 
          color: 'var(--accent)', 
          display: 'flex', 
          alignItems: 'center', 
          gap: '4px',
          fontWeight: 500
        }}
      >
        🔮 Viz
      </Link>
      <LanguageSwitcher />
    </nav>
  )
})
