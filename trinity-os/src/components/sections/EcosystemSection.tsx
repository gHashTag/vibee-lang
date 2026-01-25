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
      
      <div className="grid-row fade" style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '15px' }}>
        {eco.items?.map((item: { title: string; desc: string }, i: number) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', border: 'none', borderLeft: '1px solid var(--border)', borderRadius: 0, background: 'transparent' }}>
            <div className="card-dot" style={{ width: '5px', height: '5px', borderRadius: '50%', background: 'var(--accent)', marginBottom: '0.8rem' }} />
            <h4 style={{ fontSize: '1rem', marginBottom: '0.4rem' }}>{item.title}</h4>
            <p style={{ margin: 0, lineHeight: '1.4', fontSize: '0.8rem' }}>{item.desc}</p>
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
