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
      
      <div className="grid fade" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(160px, 20vw, 250px), 1fr))', marginBottom: '4rem', gap: '1.5rem' }}>
        {tr.techs?.map((tech: { title: string; desc: string; tests: string }, i: number) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', border: 'none', borderLeft: '2px solid var(--border)', borderRadius: 0, background: 'transparent', padding: '1rem' }}>
            <h4 style={{ color: 'var(--accent)', marginBottom: '0.4rem', fontSize: '1rem' }}>{tech.title}</h4>
            <p style={{ margin: 0, fontSize: '0.8rem', opacity: 0.8 }}>{tech.desc}</p>
            <div style={{ marginTop: '0.8rem', fontSize: '0.7rem', color: 'var(--accent)', opacity: 0.7, fontWeight: 500 }}>{tech.tests}</div>
          </div>
        ))}
      </div>

      <div className="grid fade" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(140px, 15vw, 180px), 1fr))', gap: '20px', alignItems: 'center' }}>
        {displayMetrics?.map((m: { value: string; label: string; color: string }, i: number) => (
          <div key={i} style={{ width: '100%' }}>
            <MetricCard value={m.value} label={m.label} color={m.color as any} />
          </div>
        ))}
      </div>
    </Section>
  )
}
