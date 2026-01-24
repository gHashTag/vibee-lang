import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function EcosystemSection() {
  const { t } = useI18n()
  const eco = t.ecosystem

  if (!eco) return null

  return (
    <Section id="ecosystem">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: eco.title }} />
      <p className="fade" style={{ marginBottom: '4rem' }}>{eco.sub}</p>
      
      <div className="grid fade">
        {eco.items?.map((item, i) => (
          <div key={i} className="premium-card">
            <div className="card-dot" style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--accent)', marginBottom: '1.5rem' }} />
            <h3>{item.title}</h3>
            <p style={{ textAlign: 'left', margin: 0, fontSize: '0.95rem' }}>{item.desc}</p>
          </div>
        ))}
      </div>

      <div className="fade" style={{ marginTop: '6rem', width: '100%', maxWidth: '800px' }}>
        <p style={{ fontStyle: 'italic', marginBottom: '2rem', color: 'var(--text)' }}>"{eco.quote}"</p>
        <div className="formula-box">
          {eco.formula}
        </div>
      </div>
    </Section>
  )
}
