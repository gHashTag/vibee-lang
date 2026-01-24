import { useI18n } from '../../i18n/context'
import Section from '../Section'
import MetricCard from '../MetricCard'

export default function InvestSection() {
  const { t } = useI18n()
  const inv = t.invest
  
  return (
    <Section id="invest">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: inv.title }} />
      
      <div className="grid fade" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '3rem', margin: '4rem 0' }}>
        {inv?.cards?.map((card, i) => (
          <div key={i} className="premium-card">
            <h3 style={{ fontSize: '3rem', marginBottom: '0.5rem' }}>{card.value}</h3>
            <p style={{ fontSize: '1.2rem' }}>{card.label}</p>
          </div>
        ))}
      </div>
      
      <p className="closing fade" style={{ fontSize: '1.5rem', fontWeight: 500, color: 'var(--text)' }}>{inv?.closing}</p>
      
      <div className="cta-grid fade" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '1.5rem', marginTop: '3rem' }}>
        <div className="glass" style={{ padding: '1.5rem', textAlign: 'center' }}>
          <h4>Investors</h4>
          <a href={`mailto:${inv?.contact?.email}?subject=Pitch Deck Request`} className="btn" style={{ width: '100%', marginTop: '1rem' }}>
            {inv?.ctas?.investor}
          </a>
        </div>
        <div className="glass" style={{ padding: '1.5rem', textAlign: 'center' }}>
          <h4>Partners</h4>
          <a href={`mailto:${inv?.contact?.email}?subject=Integration Inquiry`} className="btn secondary" style={{ width: '100%', marginTop: '1rem' }}>
            {inv?.ctas?.partner}
          </a>
        </div>
        <div className="glass" style={{ padding: '1.5rem', textAlign: 'center' }}>
          <h4>Talents</h4>
          <a href="https://t.me/vibee_dev" className="btn telegram" style={{ width: '100%', marginTop: '1rem' }}>
            {inv?.ctas?.talent}
          </a>
        </div>
      </div>

      <div className="cta-buttons fade" style={{ marginTop: '3rem', justifyContent: 'center' }}>
        <a href={inv?.contact?.github} className="btn secondary" target="_blank" rel="noopener">GitHub</a>
      </div>
    </Section>
  )
}
