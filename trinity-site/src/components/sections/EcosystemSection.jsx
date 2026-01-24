import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function EcosystemSection() {
  const { t } = useI18n()
  const eco = t.ecosystem

  if (!eco) return null

  return (
    <Section id="ecosystem">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: eco.title }} />
      <p className="sub fade" style={{ opacity: 0.8, maxWidth: '800px', margin: '1rem auto 3rem' }}>{eco.sub}</p>
      
      <div className="glass fade" style={{ padding: '2rem', marginBottom: '3rem', border: '1px solid var(--accent-blue-alpha)' }}>
        <p style={{ fontStyle: 'italic', fontSize: '1.2rem', lineHeight: '1.6', marginBottom: '1.5rem' }}>"{eco.quote}"</p>
        <div className="formula-box" style={{ 
          background: 'rgba(0,0,0,0.3)', 
          padding: '1.5rem', 
          borderRadius: '12px',
          fontFamily: 'monospace',
          fontSize: '1.4rem',
          color: 'var(--accent-blue)',
          borderLeft: '4px solid var(--accent-blue)'
        }}>
          {eco.formula}
        </div>
      </div>

      <div className="grid fade" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '1.5rem' }}>
        {eco.items?.map((item, i) => (
          <div key={i} className="premium-card" style={{ textAlign: 'left', padding: '1.5rem' }}>
            <h3 style={{ fontSize: '1.3rem', marginBottom: '0.5rem', color: 'var(--accent-blue)' }}>{item.title}</h3>
            <p style={{ fontSize: '0.95rem', opacity: 0.9, lineHeight: '1.4' }}>{item.desc}</p>
          </div>
        ))}
      </div>
    </Section>
  )
}
