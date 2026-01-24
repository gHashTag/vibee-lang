import { useI18n } from '../../i18n/context'
import MetricCard from '../MetricCard'

export default function TractionSection() {
  const { t } = useI18n()
  const tr = t.traction
  
  return (
    <section id="traction">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: tr.title }} />
      <p className="fade" style={{ marginBottom: '4rem' }}>{tr.sub}</p>
      
      <div className="grid fade">
        {tr?.techs?.map((tech, i) => (
          <div key={i} className="premium-card">
            <h4 style={{ color: 'var(--accent)', marginBottom: '0.5rem' }}>{tech.title}</h4>
            <p style={{ textAlign: 'left', margin: 0, fontSize: '0.9rem' }}>{tech.desc}</p>
            <div style={{ marginTop: '1rem', fontSize: '0.8rem', color: 'var(--accent)' }}>{tech.tests}</div>
          </div>
        ))}
      </div>

      <div className="grid fade" style={{ marginTop: '4rem' }}>
        {tr?.metrics?.map((m, i) => (
          <MetricCard key={i} value={m.value} label={m.label} color={m.color} />
        ))}
      </div>
    </section>
  )
}
