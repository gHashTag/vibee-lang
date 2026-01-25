"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function MilestonesSection() {
  const { t } = useI18n()
  const m = t.milestones

  if (!m) return null

  return (
    <Section id="milestones">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: m.title }} />
        <p>{m.sub}</p>
      </div>
      
      <div className="grid-row fade" style={{ marginTop: '3rem' }}>
        {m.quarters?.map((q, i) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', background: 'rgba(255,255,255,0.02)' }}>
            <div style={{ fontSize: '0.65rem', color: 'var(--accent)', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{q.q}</div>
            <h4 style={{ marginBottom: '0.8rem', fontSize: '1rem' }}>{q.title}</h4>
            {q.items?.map((item, j) => (
              <div key={j} style={{ fontSize: '0.75rem', color: 'var(--muted)', marginBottom: '0.3rem' }}>• {item}</div>
            ))}
          </div>
        ))}
      </div>

      <div className="fade" style={{ marginTop: '2rem', display: 'flex', gap: '2rem', justifyContent: 'center', flexWrap: 'wrap' }}>
        {m.success?.map((s, i) => (
          <div key={i} style={{ fontSize: '0.85rem', color: 'var(--accent)' }}>✓ {s}</div>
        ))}
      </div>
    </Section>
  )
}
