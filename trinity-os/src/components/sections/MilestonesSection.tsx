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
      
      <div className="grid fade" style={{ 
        marginTop: 'clamp(2rem, 5vw, 3rem)', 
        gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(200px, 28vw, 350px), 1fr))', 
        gap: 'clamp(0.8rem, 2vw, 1.5rem)' 
      }}>
        {m.quarters?.map((q: { q: string; title: string; items: string[] }, i: number) => (
          <div key={i} className="premium-card compact" style={{ 
            textAlign: 'left', 
            background: 'rgba(255,255,255,0.015)', 
            padding: 'clamp(1rem, 3vw, 1.5rem)',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'flex-start'
          }}>
            <div style={{ fontSize: '0.6rem', color: 'var(--accent)', marginBottom: '0.2rem', textTransform: 'uppercase', letterSpacing: '0.15em' }}>{q.q}</div>
            <h4 style={{ marginBottom: '0.6rem', fontSize: 'clamp(0.9rem, 2.5vw, 1rem)', fontWeight: 600 }}>{q.title}</h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
              {q.items?.map((item: string, j: number) => (
                <div key={j} style={{ fontSize: '0.75rem', color: 'var(--muted)', lineHeight: 1.3, display: 'flex', gap: '0.5rem' }}>
                  <span style={{ color: 'var(--accent)', opacity: 0.7 }}>•</span>
                  <span>{item}</span>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="fade" style={{ marginTop: '2rem', display: 'flex', gap: '2rem', justifyContent: 'center', flexWrap: 'wrap' }}>
        {m.success?.map((s: string, i: number) => (
          <div key={i} style={{ fontSize: '0.85rem', color: 'var(--accent)' }}>✓ {s}</div>
        ))}
      </div>
    </Section>
  )
}
