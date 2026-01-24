import { useI18n } from '../../i18n/context.jsx'
import Section from '../Section.jsx'

export default function TechAssetsSection() {
  const { t } = useI18n()
  const ta = t.techAssets

  if (!ta) return null

  return (
    <Section id="tech-assets">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: ta.title }} />
        <p>{ta.sub}</p>
      </div>
      
      <div className="grid-row fade" style={{ marginTop: '3rem' }}>
        {ta.items?.map((item, i) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', minHeight: '140px' }}>
            <div style={{ fontSize: '2rem', fontWeight: 600, color: 'var(--accent)', marginBottom: '0.2rem' }}>{item.value}</div>
            <div style={{ fontSize: '0.9rem', fontWeight: 500, color: 'var(--text)', marginBottom: '0.5rem' }}>{item.label}</div>
            <div style={{ fontSize: '0.8rem', color: 'var(--muted)' }}>{item.desc}</div>
          </div>
        ))}
      </div>
    </Section>
  )
}
