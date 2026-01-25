import { useI18n } from '../../i18n/context'
import Section from '../Section'
import MetricCard from '../MetricCard'

export default function SolutionSection() {
  const { t } = useI18n()
  const s = t.solution
  
  if (!s) return null

  return (
    <Section id="solution">
      <div className="radial-glow" style={{ opacity: 0.3 }} />
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: s.title }} />
      </div>
      
      <div className="fade" style={{ display: 'flex', alignItems: 'center', gap: 'clamp(2rem, 8vw, 6rem)', margin: '3rem 0', flexWrap: 'wrap', justifyContent: 'center' }}>
        <div style={{ width: 'clamp(180px, 25vw, 220px)', height: 'clamp(180px, 25vw, 220px)', flexShrink: 0 }}>
          <svg viewBox="0 0 100 100" style={{ filter: 'drop-shadow(0 0 15px rgba(0, 229, 153, 0.15))' }}>
            <circle cx="50" cy="50" r="45" fill="none" stroke="var(--border)" strokeWidth="0.5" />
            <circle 
              cx="50" cy="50" r="45" fill="none" stroke="var(--accent)" strokeWidth="2.5" 
              strokeDasharray="283"
              strokeDashoffset="134"
              strokeLinecap="round"
              style={{ transform: 'rotate(-90deg)', transformOrigin: 'center' }}
            />
            <text x="50" y="38" textAnchor="middle" dominantBaseline="middle" fill="var(--text)" fontSize="6" fontWeight="400" opacity="0.4">
              log₂(3)
            </text>
            <text x="50" y="58" textAnchor="middle" dominantBaseline="middle" fill="var(--accent)" fontSize="24" fontWeight="600">
              1.58
            </text>
          </svg>
        </div>
        <div style={{ textAlign: 'left', minWidth: '280px' }}>
          {s.legend?.map((item: string, i: number) => (
            <div 
               key={i} 
               className={`anim-fade-in-up anim-delay-${i + 1}`}
               style={{ display: 'flex', alignItems: 'center', gap: '0.8rem', marginBottom: '0.8rem' }}
            >
              <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: i === 0 ? 'var(--accent)' : 'var(--border)' }} />
              <span style={{ fontSize: '0.85rem', color: i === 0 ? 'var(--text)' : 'rgba(255,255,255,0.6)', letterSpacing: '0.02em' }}>{item}</span>
            </div>
          ))}
        </div>
      </div>
      
      <div className="grid-row fade" style={{ gap: '1rem', alignItems: 'stretch' }}>
        {s.cards?.map((card: { value: string; label: string; color: string }, i: number) => (
          <div
            key={i}
            className={`anim-fade-in-up anim-delay-${Math.min(i + 1, 5)}`}
            style={{ flex: '1 1 120px', maxWidth: '180px' }}
          >
            <MetricCard value={card.value} label={card.label} color={card.color as any} />
          </div>
        ))}
      </div>
    </Section>
  )
}
