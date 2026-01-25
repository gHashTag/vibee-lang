"use client";
import { useI18n } from '../../i18n/context';

export default function HeroSection() {
  const { t: { hero: t } } = useI18n(); 
  
  return (
    <section id="hero">
      <div className="radial-glow" />
      <div className="fade" style={{ color: 'var(--accent)', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.3em', marginBottom: '1rem' }}>{t.tag}</div>
      <h1 className="fade" style={{ marginBottom: '1rem' }}>TRINITY</h1>
      <div className="fade" style={{ fontSize: '1.5rem', opacity: 0.6, marginBottom: '2.5rem', fontFamily: 'serif', fontStyle: 'italic' }}>φ² + 1/φ² = 3</div>
      <h2 className="fade" style={{ fontSize: 'clamp(1.5rem, 4vw, 2.5rem)', marginBottom: '1.5rem' }} dangerouslySetInnerHTML={{ __html: t.headline }} />
      <p className="fade" style={{ fontSize: '1.1rem', marginBottom: '3rem', opacity: 0.8 }}>{t.quote}</p>
      
      <div className="fade" style={{ display: 'flex', gap: '1rem', marginTop: '2.5rem', justifyContent: 'center' }}>
        <a href="#invest" className="btn">{t.cta}</a>
        <a href="#ecosystem" className="btn secondary">{t.ctaSecondary}</a>
      </div>
    </section>
  )
}