import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function HeroSection() {
  const { t } = useI18n()
  
  return (
    <Section id="hero">
      <div className="fade" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '1rem' }}>
        <p className="tag" dangerouslySetInnerHTML={{ __html: t.hero?.tag }} style={{ letterSpacing: '0.4em' }} />
        <h1 style={{ fontSize: 'clamp(60px, 12vw, 120px)', margin: '1rem 0' }}>TRINITY</h1>
        <h2 className="headline" style={{ fontSize: '2rem', fontWeight: 500, color: 'var(--text)', opacity: 0.8 }}
            dangerouslySetInnerHTML={{ __html: t.hero?.headline }} />
        <p className="formula" style={{ fontSize: '1.5rem', margin: '2rem 0' }}>φ² + 1/φ² = 3</p>
        <a href="#invest" className="btn" style={{ padding: '20px 48px', fontSize: '18px' }}>{t.hero?.cta}</a>
        <p className="sub" style={{ marginTop: '2rem', maxWidth: '600px' }} dangerouslySetInnerHTML={{ __html: t.hero?.desc }} />
      </div>
    </Section>
  )
}
