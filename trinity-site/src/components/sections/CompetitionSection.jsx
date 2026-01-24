import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function CompetitionSection() {
  const { t } = useI18n()
  const c = t.competition
  
  return (
    <Section id="competition">
      <div className="radial-glow" style={{ opacity: 0.2 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: c.title }} />
      
      <div className="fade" style={{ marginTop: '4rem', width: '100%', maxWidth: '900px', textAlign: 'left' }}>
        <div style={{ borderTop: '1px solid var(--border)' }}>
          {c?.rows?.map((row, i) => (
            <div key={i} style={{ 
              display: 'grid', 
              gridTemplateColumns: '2fr 1.5fr 1fr 1fr 1fr', 
              padding: '1.5rem 0', 
              borderBottom: '1px solid var(--border)',
              background: row.company === 'TRINITY' ? 'rgba(0, 229, 153, 0.05)' : 'transparent'
            }}>
              <div style={{ color: row.company === 'TRINITY' ? 'var(--accent)' : 'var(--text)', fontSize: '0.9rem', fontWeight: 500 }}>{row.company}</div>
              <div style={{ color: 'var(--muted)', fontSize: '0.8rem' }}>{row.arch}</div>
              <div style={{ color: 'var(--muted)', fontSize: '0.8rem' }}>{row.val}</div>
              <div style={{ color: row.ternary ? 'var(--accent)' : '#ff453a', fontSize: '1rem' }}>{row.ternary ? '✓' : '✗'}</div>
              <div style={{ color: row.open ? 'var(--accent)' : '#ff453a', fontSize: '1rem' }}>{row.open ? '✓' : '✗'}</div>
            </div>
          ))}
        </div>
        <p className="fade" style={{ marginTop: '2rem', fontSize: '0.9rem', textAlign: 'center' }} dangerouslySetInnerHTML={{ __html: c.note }} />
      </div>
    </Section>
  )
}
