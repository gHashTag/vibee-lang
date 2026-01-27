import { useState, useEffect, memo } from 'react'
import { useI18n } from '../i18n/context'
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
      <a 
        href="/play" 
        style={{ 
          color: 'var(--accent)', 
          display: 'flex', 
          alignItems: 'center', 
          gap: '6px',
          fontWeight: 600,
          textDecoration: 'none',
          padding: '6px 14px',
          background: 'rgba(0, 229, 153, 0.1)',
          border: '1px solid rgba(0, 229, 153, 0.3)',
          borderRadius: '20px',
          marginLeft: '8px',
          transition: 'all 0.2s'
        }}
        onMouseEnter={(e) => {
           e.currentTarget.style.background = 'rgba(0, 229, 153, 0.2)';
           e.currentTarget.style.borderColor = 'var(--accent)';
           e.currentTarget.style.boxShadow = '0 0 10px rgba(0,229,153,0.2)';
        }}
        onMouseLeave={(e) => {
           e.currentTarget.style.background = 'rgba(0, 229, 153, 0.1)';
           e.currentTarget.style.borderColor = 'rgba(0, 229, 153, 0.3)';
           e.currentTarget.style.boxShadow = 'none';
        }}
      >
        <span>⚡</span> Playground
      </a>
      <LanguageSwitcher />
    </nav>
  )
})
