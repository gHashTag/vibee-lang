"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function InvestSection() {
  const { t } = useI18n()
  const inv = t.invest
  
  return (
    <Section id="invest">
      <div className="radial-glow" style={{ opacity: 0.4 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: inv.title }} />
      
      <div className="grid fade">
        {inv?.cards?.map((card: { value: string; label: string }, i: number) => (
          <div key={i} className="premium-card" style={{ textAlign: 'center' }}>
            <h3 style={{ fontSize: '3rem', fontWeight: 500, marginBottom: '0.5rem' }}>{card.value}</h3>
            <p style={{ fontSize: '0.9rem', color: 'var(--muted)' }}>{card.label}</p>
          </div>
        ))}
      </div>
      
      <p className="fade" style={{ fontSize: '1.2rem', margin: '4rem 0', fontStyle: 'italic', maxWidth: '700px' }}>{inv?.closing}</p>
      
      <div className="grid fade" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(200px, 25vw, 300px), 1fr))', gap: '1.5rem' }}>
        <div className="premium-card" style={{ textAlign: 'center', padding: 'clamp(1.5rem, 4vw, 2rem)', display: 'flex', flexDirection: 'column' }}>
          <h4 style={{ marginBottom: '1.5rem', fontWeight: 500, fontSize: 'clamp(1rem, 3vw, 1.2rem)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{inv.investorTitle}</h4>
          <div style={{ marginTop: 'auto' }}>
            <a href={`mailto:${inv?.contact?.email}?subject=Pitch Deck Request`} className="btn" style={{ width: '100%', fontSize: '0.9rem' }}>
              {inv?.ctas?.investor}
            </a>
          </div>
        </div>
        <div className="premium-card" style={{ textAlign: 'center', padding: 'clamp(1.5rem, 4vw, 2rem)', display: 'flex', flexDirection: 'column' }}>
          <h4 style={{ marginBottom: '1.5rem', fontWeight: 500, fontSize: 'clamp(1rem, 3vw, 1.2rem)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{inv.partnerTitle}</h4>
          <div style={{ marginTop: 'auto' }}>
            <a href={`mailto:${inv?.contact?.email}?subject=Integration Inquiry`} className="btn secondary" style={{ width: '100%', fontSize: '0.9rem' }}>
              {inv?.ctas?.partner}
            </a>
          </div>
        </div>
        <div className="premium-card" style={{ textAlign: 'center', padding: 'clamp(1.5rem, 4vw, 2rem)', display: 'flex', flexDirection: 'column' }}>
          <h4 style={{ marginBottom: '1.5rem', fontWeight: 500, fontSize: 'clamp(1rem, 3vw, 1.2rem)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{inv.talentTitle}</h4>
          <div style={{ marginTop: 'auto' }}>
            <a href="https://t.me/vibee_dev" className="btn secondary" style={{ width: '100%', borderColor: '#229ED9', color: '#229ED9', fontSize: '0.9rem' }}>
              {inv?.ctas?.talent}
            </a>
          </div>
        </div>
      </div>

      <div className="fade" style={{ marginTop: '4rem' }}>
        <a href={inv?.contact?.github} className="btn secondary" target="_blank" rel="noopener">{inv.ctaGithub}</a>
      </div>
    </Section>
  )
}
