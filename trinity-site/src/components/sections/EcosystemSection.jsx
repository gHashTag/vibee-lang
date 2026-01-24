import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function EcosystemSection() {
  const { t } = useI18n()
  const eco = t.ecosystem

  if (!eco) return null

  return (
    <Section id="ecosystem">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: eco.title }} />
      <p className="fade" style={{ marginBottom: '3rem' }}>{eco.sub}</p>
      
      <div className="grid-row fade" style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '15px' }}>
        {eco.items?.map((item, i) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', border: 'none', borderLeft: '1px solid var(--border)', borderRadius: 0, background: 'transparent' }}>
            <div className="card-dot" style={{ width: '6px', height: '6px', borderRadius: '50%', background: 'var(--accent)', marginBottom: '1rem' }} />
            <h4 style={{ fontSize: '1.1rem', marginBottom: '0.5rem' }}>{item.title}</h4>
            <p style={{ margin: 0, lineHeight: '1.4' }}>{item.desc}</p>
          </div>
        ))}
      </div>

      <div className="fade" style={{ marginTop: '5rem', width: '100%' }}>
        <p style={{ fontStyle: 'italic', marginBottom: '2rem', color: 'var(--muted)', fontSize: '0.95rem' }}>"{eco.quote}"</p>
        <div className="formula-box">
          {eco.formula}
        </div>
      </div>
    </Section>
  )
}
