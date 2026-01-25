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
      
      <div className="grid fade" style={{ 
        gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(140px, 45%, 300px), 1fr))', 
        gap: 'clamp(0.8rem, 2vw, 1.5rem)' 
      }}>
        {eco.items?.map((item: { title: string; desc: string }, i: number) => (
          <div key={i} className="premium-card compact" style={{ 
            textAlign: 'left', 
            border: 'none', 
            borderLeft: '1px solid var(--border)', 
            borderRadius: 0, 
            background: 'transparent', 
            padding: '0.8rem 1rem' 
          }}>
            <div className="card-dot" style={{ width: '5px', height: '5px', borderRadius: '50%', background: 'var(--accent)', marginBottom: '0.6rem' }} />
            <h4 style={{ fontSize: '0.9rem', marginBottom: '0.3rem', color: 'var(--text)', fontWeight: 600 }}>{item.title}</h4>
            <p style={{ margin: 0, lineHeight: '1.3', fontSize: '0.75rem', opacity: 0.7 }}>{item.desc}</p>
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
