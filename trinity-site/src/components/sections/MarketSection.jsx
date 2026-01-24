import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function MarketSection() {
  const { t } = useI18n()
  const m = t.market
  
  if (!m) return null

  return (
    <Section id="market">
      <div className="radial-glow" style={{ opacity: 0.3 }} />
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: m.title }} />
      </div>
      
      <div className="grid fade">
        {m?.funnel?.map((item, i) => (
          <div key={i} className="premium-card" style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '3rem', fontWeight: 500, color: i === 2 ? 'var(--accent)' : 'var(--text)', marginBottom: '0.5rem' }}>{item.value}</div>
            <div style={{ color: 'var(--muted)', fontSize: '0.9rem' }}>{item.label}</div>
          </div>
        ))}
      </div>
      
      <div className="fade" style={{ marginTop: '4rem', width: '100%', maxWidth: '800px', overflowX: 'auto' }}>
        <h3 style={{ fontSize: '1.2rem', marginBottom: '1.5rem', fontWeight: 500, textAlign: 'center' }}>{m.compsTitle}</h3>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
          <thead>
            <tr>
              {m.headers?.map((h, i) => (
                <th key={i} style={{ 
                  padding: '0.8rem', 
                  borderBottom: '1px solid var(--border)', 
                  color: 'var(--muted)', 
                  textAlign: 'center', 
                  fontWeight: '500',
                  fontSize: '0.75rem',
                  textTransform: 'uppercase',
                  letterSpacing: '0.1em'
                }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {m?.rows?.map((row, i) => (
              <tr key={i} style={{ background: row[0] === 'TRINITY' ? 'rgba(0, 229, 153, 0.05)' : 'transparent' }}>
                {row?.map((cell, j) => (
                  <td key={j} style={{ 
                    padding: '0.8rem', 
                    borderBottom: '1px solid var(--border)', 
                    textAlign: 'center',
                    color: row[0] === 'TRINITY' && j === 0 ? 'var(--accent)' : j === 0 ? 'var(--text)' : 'var(--muted)',
                    fontWeight: j === 0 ? 500 : 400
                  }}>{cell}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Section>
  )
}
