"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function ProductSection() {
  const { t } = useI18n()
  const p = t.product

  if (!p) return null

  return (
    <Section id="product">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: p.title }} />
      </div>
      
      <div className="grid fade" style={{ marginTop: '3rem', gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(180px, 20vw, 250px), 1fr))', gap: '1.5rem' }}>
        {p.phases?.map((phase: { year: string; phase: string; desc: string }, i: number) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', border: 'none', borderLeft: '2px solid var(--border)', borderRadius: 0, background: 'transparent', padding: '1rem' }}>
            <div style={{ fontSize: '0.65rem', color: 'var(--accent)', marginBottom: '0.4rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{phase.year}</div>
            <h4 style={{ marginBottom: '0.6rem', fontSize: '1.1rem' }}>{phase.phase}</h4>
            <p style={{ color: 'var(--muted)', lineHeight: '1.4', fontSize: '0.8rem', margin: 0 }}>{phase.desc}</p>
          </div>
        ))}
      </div>
    </Section>
  )
}
