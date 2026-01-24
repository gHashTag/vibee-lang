import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function GTMSection() {
  const { t } = useI18n()
  const gtm = t.gtm
  
  return (
    <Section id="gtm">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: gtm?.title }} style={{ marginBottom: '3rem' }} />
      <div className="grid fade" style={{ gridTemplateColumns: 'repeat(3, 1fr)', gap: '1rem', textAlign: 'left' }}>
        {gtm?.phases?.map((phase, i) => (
          <div key={i} className="premium-card" style={{ padding: '1.5rem', background: 'transparent', border: 'none', borderLeft: '1px solid var(--border)', borderRadius: 0 }}>
            <div style={{ fontSize: '0.7rem', color: 'var(--accent)', fontWeight: 500, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{phase.phase}</div>
            <h4 style={{ fontSize: '1.2rem', marginBottom: '0.8rem', fontWeight: 500 }}>{phase.title}</h4>
            <p style={{ margin: 0, fontSize: '0.85rem', lineHeight: '1.5', color: 'var(--muted)' }}>{phase.desc}</p>
          </div>
        ))}
      </div>
    </Section>
  )
}
