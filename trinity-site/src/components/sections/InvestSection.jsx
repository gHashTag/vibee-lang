import { useI18n } from '../../i18n/context'
import Section from '../Section'
import MetricCard from '../MetricCard'

export default function InvestSection() {
  const { t } = useI18n()
  const inv = t.invest
  
  return (
    <Section id="invest">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: inv.title }} />
      
      <div className="invest-grid fade">
        <div className="glass use-funds">
          <h3>{inv.useTitle}</h3>
          <ul>
            {inv?.uses?.map((use, i) => <li key={i}>{use}</li>)}
          </ul>
        </div>
        
        <div className="invest-cards">
          {inv?.cards?.map((card, i) => (
            <MetricCard key={i} value={card.value} label={card.label} color={i === 0 ? 'green' : 'blue'} />
          ))}
        </div>
      </div>
      
      <div className="milestones-grid fade">
        <div className="glass">
          <h3>{inv.milestonesTitle}</h3>
          <ul>
            {inv?.milestones?.map((m, i) => <li key={i}>{m}</li>)}
          </ul>
        </div>
        
        <div className="glass">
          <h3>{inv.whyTitle}</h3>
          <ul>
            {inv?.why?.map((w, i) => <li key={i}>{w}</li>)}
          </ul>
        </div>
      </div>
      
      <p className="closing fade">{inv?.closing}</p>
      
      <div className="cta-grid fade" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '1.5rem', marginTop: '3rem' }}>
        <div className="glass" style={{ padding: '1.5rem', textAlign: 'center' }}>
          <h4>Investors</h4>
          <a href="mailto:raoffonom@icloud.com?subject=Pitch Deck Request" className="btn" style={{ width: '100%', marginTop: '1rem' }}>
            {inv?.ctas?.investor}
          </a>
        </div>
        <div className="glass" style={{ padding: '1.5rem', textAlign: 'center' }}>
          <h4>Partners</h4>
          <a href="mailto:raoffonom@icloud.com?subject=Integration Inquiry" className="btn secondary" style={{ width: '100%', marginTop: '1rem' }}>
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
        <a href="https://github.com/gHashTag/vibee-lang" className="btn secondary" target="_blank" rel="noopener">GitHub</a>
      </div>
    </Section>
  )
}
