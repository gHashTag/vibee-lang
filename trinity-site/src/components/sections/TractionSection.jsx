import { useI18n } from '../../i18n/context'
import MetricCard from '../MetricCard'

export default function TractionSection() {
  const { t } = useI18n()
  const tr = t.traction
  
  if (!tr) return null

  return (
    <section id="traction">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: tr.title }} />
      <p className="fade" style={{ marginBottom: '3rem' }}>{tr.sub}</p>
      
      <div className="grid-row fade" style={{ marginBottom: '3rem' }}>
        {tr.techs?.map((tech, i) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', border: 'none', borderLeft: '1px solid var(--border)', borderRadius: 0, background: 'transparent' }}>
            <h4 style={{ color: 'var(--accent)', marginBottom: '0.5rem' }}>{tech.title}</h4>
            <p style={{ margin: 0 }}>{tech.desc}</p>
            <div style={{ marginTop: '0.8rem', fontSize: '0.75rem', color: 'var(--accent)', opacity: 0.8 }}>{tech.tests}</div>
          </div>
        ))}
      </div>

      <div className="grid-row fade">
        {tr.metrics?.map((m, i) => (
          <MetricCard key={i} value={m.value} label={m.label} color={m.color} />
        ))}
      </div>
    </section>
  )
}
