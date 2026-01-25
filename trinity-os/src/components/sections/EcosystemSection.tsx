"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function EcosystemSection() {
  const { t } = useI18n()
  const eco = t.ecosystem

  if (!eco) return null

  return (
    <Section id="ecosystem">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: eco.title }} />
        <p style={{ marginBottom: '4rem' }}>{eco.sub}</p>
      </div>
      
      <div className="grid fade" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(200px, 25vw, 320px), 1fr))', gap: '1.5rem' }}>
        {eco.items?.map((item: { title: string; desc: string }, i: number) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', border: 'none', borderLeft: '2px solid var(--border)', borderRadius: 0, background: 'transparent', padding: '1rem' }}>
            <div className="card-dot" style={{ width: '6px', height: '6px', borderRadius: '50%', background: 'var(--accent)', marginBottom: '0.8rem' }} />
            <h4 style={{ fontSize: '1rem', marginBottom: '0.4rem', color: 'var(--text)' }}>{item.title}</h4>
            <p style={{ margin: 0, lineHeight: '1.4', fontSize: '0.8rem', opacity: 0.8 }}>{item.desc}</p>
          </div>
        ))}
      </div>

      <div className="tight fade" style={{ marginTop: '6rem' }}>
        <p style={{ fontStyle: 'italic', marginBottom: '2rem', color: 'var(--muted)', fontSize: '0.9rem' }}>"{eco.quote}"</p>
        <div className="formula-box" style={{ fontSize: '1rem', padding: '1rem' }}>
          {eco.formula}
        </div>
      </div>
    </Section>
  )
}
