import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function GTMSection() {
  const { t } = useI18n()
  const gtm = t.gtm
  
  if (!gtm) return null

  return (
    <Section id="gtm">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: gtm.title }} style={{ marginBottom: '3rem' }} />
      <div className="grid-row fade">
        {gtm.phases?.map((phase, i) => (
          <div key={i} className="premium-card compact fade" style={{ transitionDelay: `${i * 100}ms`, textAlign: 'left', background: 'transparent', border: 'none', borderLeft: '1px solid var(--border)', borderRadius: 0 }}>
            <div style={{ fontSize: '0.7rem', color: 'var(--accent)', marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{phase.phase}</div>
            <h4 style={{ marginBottom: '0.8rem' }}>{phase.title}</h4>
            <p style={{ color: 'var(--muted)', lineHeight: '1.4' }}>{phase.desc}</p>
          </div>
        ))}
      </div>
    </Section>
  )
}
