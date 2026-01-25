"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'
import MetricCard from '../MetricCard'

export default function TractionSection() {
  const { t } = useI18n()
  const tr = t.traction
  
  if (!tr) return null

  // Ensure 6 items for symmetry
  const displayMetrics = tr.metrics?.slice(0, 6)

  return (
    <Section id="traction">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: tr.title }} />
        <p style={{ marginBottom: '4rem' }}>{tr.sub}</p>
      </div>
      <h3 className="fade" style={{ fontSize: '0.85rem', color: 'var(--accent)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '2rem' }}>{tr.techTitle}</h3>
      
      <div className="grid-row fade" style={{ marginBottom: '4rem' }}>
        {tr.techs?.map((tech: { title: string; desc: string; tests: string }, i: number) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', border: 'none', borderLeft: '1px solid var(--border)', borderRadius: 0, background: 'transparent' }}>
            <h4 style={{ color: 'var(--accent)', marginBottom: '0.4rem', fontSize: '0.9rem' }}>{tech.title}</h4>
            <p style={{ margin: 0, fontSize: '0.75rem' }}>{tech.desc}</p>
            <div style={{ marginTop: '0.6rem', fontSize: '0.65rem', color: 'var(--accent)', opacity: 0.7 }}>{tech.tests}</div>
          </div>
        ))}
      </div>

      <div className="grid-row fade" style={{ gap: '10px' }}>
        {displayMetrics?.map((m: { value: string; label: string; color: string }, i: number) => (
          <MetricCard key={i} value={m.value} label={m.label} color={m.color as any} />
        ))}
      </div>
    </Section>
  )
}
