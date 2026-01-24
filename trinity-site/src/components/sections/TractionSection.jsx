import { useI18n } from '../../i18n/context'
import MetricCard from '../MetricCard'

export default function TractionSection() {
  const { t } = useI18n()
  const tr = t.traction
  
  if (!tr) return null

  return (
    <section id="traction">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: tr.title }} />
        <p style={{ marginBottom: '4rem' }}>{tr.sub}</p>
      </div>
      
      <div className="grid-row fade" style={{ marginBottom: '4rem' }}>
        {tr.techs?.map((tech, i) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', border: 'none', borderLeft: '1px solid var(--border)', borderRadius: 0, background: 'transparent' }}>
            <h4 style={{ color: 'var(--accent)', marginBottom: '0.4rem', fontSize: '0.9rem' }}>{tech.title}</h4>
            <p style={{ margin: 0, fontSize: '0.75rem' }}>{tech.desc}</p>
            <div style={{ marginTop: '0.6rem', fontSize: '0.65rem', color: 'var(--accent)', opacity: 0.7 }}>{tech.tests}</div>
          </div>
        ))}
      </div>

      <div className="grid-row fade">
        {tr.metrics?.map((m, i) => (
          <MetricCard key={i} value={m.value} label={m.label} color={m.color} />
        ))}
        {/* Fill to 6 items if needed for symmetry, or just center the 4 */}
      </div>
    </section>
  )
}
