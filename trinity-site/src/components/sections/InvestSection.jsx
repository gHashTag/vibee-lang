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
            {inv.uses.map((use, i) => <li key={i}>{use}</li>)}
          </ul>
        </div>
        
        <div className="invest-cards">
          {inv.cards.map((card, i) => (
            <MetricCard key={i} value={card.value} label={card.label} color={i === 0 ? 'green' : 'blue'} />
          ))}
        </div>
      </div>
      
      <div className="milestones-grid fade">
        <div className="glass">
          <h3>{inv.milestonesTitle}</h3>
          <ul>
            {inv.milestones.map((m, i) => <li key={i}>{m}</li>)}
          </ul>
        </div>
        
        <div className="glass">
          <h3>{inv.whyTitle}</h3>
          <ul>
            {inv.why.map((w, i) => <li key={i}>{w}</li>)}
          </ul>
        </div>
      </div>
      
      <p className="closing fade">{inv.closing}</p>
      
      <div className="cta-buttons fade">
        <a href="mailto:invest@trinity-computing.io" className="btn">Email</a>
        <a href="https://github.com/gHashTag/vibee-lang" className="btn secondary" target="_blank" rel="noopener">GitHub</a>
        <a href="https://t.me/vibee_dev" className="btn telegram">Telegram</a>
      </div>
    </Section>
  )
}
