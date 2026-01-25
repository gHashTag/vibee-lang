"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function BusinessModelSection() {
  const { t } = useI18n()
  const bm = t.businessModel

  if (!bm) return null

  return (
    <Section id="businessmodel">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: bm.title }} />
      </div>
      
      <div className="grid fade" style={{ marginTop: '3rem', gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(180px, 20vw, 250px), 1fr))', gap: '1.5rem' }}>
        {bm.streams?.map((stream: { percent: string; title: string; desc: string }, i: number) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', border: 'none', borderLeft: '2px solid var(--border)', borderRadius: 0, background: 'transparent', padding: '1rem' }}>
            <div style={{ fontSize: '1.5rem', color: 'var(--accent)', marginBottom: '0.4rem', fontWeight: '600' }}>{stream.percent}</div>
            <h4 style={{ marginBottom: '0.6rem', fontSize: '1rem' }}>{stream.title}</h4>
            <p style={{ color: 'var(--muted)', lineHeight: '1.4', fontSize: '0.8rem', margin: 0 }}>{stream.desc}</p>
          </div>
        ))}
      </div>
      
      <div className="tight fade" style={{ marginTop: '2rem' }}>
        <p style={{ fontSize: '0.85rem', color: 'var(--accent)', textAlign: 'center' }}>{bm.unitEcon}</p>
      </div>
    </Section>
  )
}
