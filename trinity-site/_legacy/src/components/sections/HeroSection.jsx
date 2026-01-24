import { useI18n } from '../../i18n/context'

export default function HeroSection() {
  const { t } = useI18n()
  const hero = t.hero
  
  return (
    <section id="hero">
      <div className="radial-glow" />
      <div className="fade" style={{ color: 'var(--accent)', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.3em', marginBottom: '1rem' }}>{hero.tag}</div>
      <h1 className="fade" style={{ marginBottom: '1rem' }}>TRINITY</h1>
      <div className="fade" style={{ fontSize: '1.5rem', opacity: 0.6, marginBottom: '2.5rem', fontFamily: 'serif', fontStyle: 'italic' }}>φ² + 1/φ² = 3</div>
      <h2 className="fade" style={{ fontSize: 'clamp(1.5rem, 4vw, 2.5rem)', marginBottom: '1.5rem' }} dangerouslySetInnerHTML={{ __html: hero.headline }} />
      <p className="fade" style={{ fontSize: '1.1rem', marginBottom: '3rem', opacity: 0.8 }}>{hero.quote}</p>
      
      <div className="cta-buttons fade">
        <a href="#invest" className="btn">{hero.cta}</a>
        <a href="#ecosystem" className="btn secondary" style={{ marginLeft: '1rem' }}>View Ecosystem</a>
      </div>
    </section>
  )
}
