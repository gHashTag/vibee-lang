import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function MarketSection() {
  const { t } = useI18n()
  const m = t.market
  
  return (
    <Section id="market">
      <div className="radial-glow" style={{ opacity: 0.3 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: m.title }} />
      
      <div className="grid fade">
        {m?.funnel?.map((item, i) => (
          <div key={i} className="premium-card" style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '3rem', fontWeight: 500, color: i === 2 ? 'var(--accent)' : 'var(--text)', marginBottom: '0.5rem' }}>{item.value}</div>
            <div style={{ color: 'var(--muted)', fontSize: '0.9rem' }}>{item.label}</div>
          </div>
        ))}
      </div>
      
      <div className="fade" style={{ marginTop: '6rem', width: '100%', maxWidth: '900px', textAlign: 'left' }}>
        <h3 style={{ fontSize: '1.5rem', marginBottom: '2rem', fontWeight: 500 }}>{m.compsTitle}</h3>
        <div style={{ borderTop: '1px solid var(--border)' }}>
          {m?.rows?.map((row, i) => (
            <div key={i} style={{ 
              display: 'grid', 
              gridTemplateColumns: '2fr 1fr 1fr 1fr', 
              padding: '1.5rem 0', 
              borderBottom: '1px solid var(--border)',
              background: row[0] === 'TRINITY' ? 'rgba(0, 229, 153, 0.05)' : 'transparent'
            }}>
              {row?.map((cell, j) => (
                <div key={j} style={{ 
                  color: row[0] === 'TRINITY' && j === 0 ? 'var(--accent)' : j === 0 ? 'var(--text)' : 'var(--muted)',
                  fontSize: '11px',
                  textTransform: 'uppercase',
                  letterSpacing: '0.1em'
                }}>{cell}</div>
              ))}
            </div>
          ))}
        </div>
      </div>
    </Section>
  )
}
