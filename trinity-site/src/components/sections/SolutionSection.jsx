import { useI18n } from '../../i18n/context'
import Section from '../Section'
import MetricCard from '../MetricCard'

export default function SolutionSection() {
  const { t } = useI18n()
  const s = t.solution
  
  return (
    <Section id="solution">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: s.title }} />
      
      <div className="info fade">
        <div className="info-chart">
          <svg viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="45" fill="none" stroke="var(--border)" strokeWidth="2" />
            <circle cx="50" cy="50" r="45" fill="none" stroke="var(--accent)" strokeWidth="4" 
              strokeDasharray="188 95" strokeLinecap="round" transform="rotate(-90 50 50)" />
            <text x="50" y="45" textAnchor="middle" fill="var(--text)" fontSize="14" fontWeight="600">log₂(3)</text>
            <text x="50" y="62" textAnchor="middle" fill="var(--accent)" fontSize="12">1.585</text>
          </svg>
        </div>
        <div className="info-text">
          {s.legend.map((item, i) => (
            <div key={i} className="info-item">
              <div className="info-dot" style={{ background: i === 0 ? 'var(--accent)' : i === 1 ? 'var(--green)' : '#bf5af2' }} />
              <span>{item}</span>
            </div>
          ))}
        </div>
      </div>
      
      <div className="grid fade">
        {s.cards.map((card, i) => (
          <MetricCard key={i} value={card.value} label={card.label} color={card.color} />
        ))}
      </div>
    </Section>
  )
}
