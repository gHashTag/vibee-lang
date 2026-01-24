import { useI18n } from '../../i18n/context'
import Section from '../Section'
import MetricCard from '../MetricCard'

export default function SolutionSection() {
  const { t } = useI18n()
  const s = t.solution
  
  return (
    <Section id="solution">
      <div className="radial-glow" style={{ opacity: 0.3 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: s.title }} />
      
      <div className="fade" style={{ display: 'flex', alignItems: 'center', gap: '4rem', margin: '4rem 0', flexWrap: 'wrap', justifyContent: 'center' }}>
        <div style={{ width: '180px', height: '180px' }}>
          <svg viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="45" fill="none" stroke="var(--border)" strokeWidth="1" />
            <circle cx="50" cy="50" r="45" fill="none" stroke="var(--accent)" strokeWidth="3" 
              strokeDasharray="188 95" strokeLinecap="round" transform="rotate(-90 50 50)" />
            <text x="50" y="48" textAnchor="middle" fill="var(--text)" fontSize="12">log₂(3)</text>
            <text x="50" y="62" textAnchor="middle" fill="var(--accent)" fontSize="14" fontWeight="500">1.585</text>
          </svg>
        </div>
        <div style={{ textAlign: 'left' }}>
          {s?.legend?.map((item, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '1rem' }}>
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: i === 0 ? 'var(--accent)' : 'var(--border)' }} />
              <span style={{ fontSize: '1rem', color: i === 0 ? 'var(--text)' : 'var(--muted)' }}>{item}</span>
            </div>
          ))}
        </div>
      </div>
      
      <div className="grid fade">
        {s?.cards?.map((card, i) => (
          <MetricCard key={i} value={card.value} label={card.label} color={card.color} />
        ))}
      </div>
    </Section>
  )
}
