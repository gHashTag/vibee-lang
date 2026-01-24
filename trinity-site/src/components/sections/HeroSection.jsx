import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function HeroSection() {
  const { t } = useI18n()
  
  return (
    <Section id="hero">
      <p className="tag fade" dangerouslySetInnerHTML={{ __html: t.hero?.tag }} />
      <h1 className="fade" style={{ marginBottom: '0.5rem' }}>TRINITY</h1>
      <h2 className="fade headline" style={{ fontSize: '1.8rem', color: 'var(--accent)', marginBottom: '1.5rem' }}
          dangerouslySetInnerHTML={{ __html: t.hero?.headline }} />
      <p className="formula fade">φ² + 1/φ² = 3</p>
      <p className="quote fade">{t.hero?.quote}</p>
      <p className="sub fade" dangerouslySetInnerHTML={{ __html: t.hero?.desc }} />
      <a href="#invest" className="btn fade">{t.hero?.cta}</a>
    </Section>
  )
}
