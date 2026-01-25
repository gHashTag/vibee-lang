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
      
      <div className="grid-row fade" style={{ marginTop: '3rem' }}>
        {p.phases?.map((phase: { year: string; phase: string; desc: string }, i: number) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', background: 'rgba(255,255,255,0.02)' }}>
            <div style={{ fontSize: '0.65rem', color: 'var(--accent)', marginBottom: '0.4rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{phase.year}</div>
            <h4 style={{ marginBottom: '0.6rem', fontSize: '1.1rem' }}>{phase.phase}</h4>
            <p style={{ color: 'var(--muted)', lineHeight: '1.4', fontSize: '0.8rem', margin: 0 }}>{phase.desc}</p>
          </div>
        ))}
      </div>
    </Section>
  )
}
