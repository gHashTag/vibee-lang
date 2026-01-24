import { useI18n } from '../../i18n/context'

export default function HeroSection() {
  const { t } = useI18n()
  const hero = t.hero
  
  return (
    <section id="hero">
      <div className="radial-glow" />
      <h1 className="fade" dangerouslySetInnerHTML={{ __html: hero.headline }} />
      <p className="fade" style={{ fontSize: '1.25rem', marginBottom: '3rem' }}>{hero.quote}</p>
      
      <div className="cta-buttons fade">
        <a href="#invest" className="btn">{hero.cta}</a>
        <a href="#ecosystem" className="btn secondary" style={{ marginLeft: '1rem' }}>View Ecosystem</a>
      </div>
    </section>
  )
}
