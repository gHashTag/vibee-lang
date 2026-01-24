import { useI18n } from '../../i18n/context.jsx'
import Section from '../Section.jsx'

export default function BenchmarksSection() {
  const { t } = useI18n()
  const b = t.benchmarks

  if (!b) return null

  return (
    <Section id="benchmarks">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: b.title }} />
        <p>{b.sub}</p>
      </div>
      
      <div className="grid fade" style={{ marginTop: '3rem', marginBottom: '4rem' }}>
        {b.metrics?.map((item, i) => (
          <div key={i} className="premium-card" style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '2.5rem', fontWeight: 500, color: i === 0 ? 'var(--accent)' : 'var(--text)', marginBottom: '0.5rem' }}>{item.value}</div>
            <div style={{ fontSize: '0.9rem', fontWeight: 500, color: 'var(--text)', marginBottom: '0.3rem' }}>{item.label}</div>
            <div style={{ fontSize: '0.8rem', color: 'var(--muted)' }}>{item.desc}</div>
          </div>
        ))}
      </div>

      <div className="premium-card fade" style={{ maxWidth: '800px', margin: '0 auto' }}>
        <h3 style={{ fontSize: '1.1rem', marginBottom: '2rem', textAlign: 'center' }}>{b.comparison?.title}</h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {b.comparison?.rows?.map((row, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
              <div style={{ width: '180px', fontSize: '0.9rem', color: 'var(--text)', textAlign: 'right' }}>{row.model}</div>
              <div style={{ flex: 1, background: 'rgba(255,255,255,0.05)', height: '24px', borderRadius: '4px', overflow: 'hidden' }}>
                <div style={{ width: `${(row.value / 80) * 100}%`, height: '100%', background: row.color, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: '0.5rem' }}>
                  <span style={{ fontSize: '0.75rem', fontWeight: 600, color: '#000' }}>{row.value}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </Section>
  )
}
