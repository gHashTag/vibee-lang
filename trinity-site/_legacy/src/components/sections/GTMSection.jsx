import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function GTMSection() {
  const { t } = useI18n()
  const gtm = t.gtm
  
  if (!gtm) return null

  return (
    <Section id="gtm">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: gtm.title }} style={{ marginBottom: '3rem' }} />
      </div>
      <div className="grid-row fade">
        {gtm.phases?.map((phase, i) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', border: 'none', borderLeft: '1px solid var(--border)', borderRadius: 0, background: 'transparent' }}>
            <div style={{ fontSize: '0.65rem', color: 'var(--accent)', marginBottom: '0.4rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{phase.phase}</div>
            <h4 style={{ marginBottom: '0.6rem', fontSize: '1rem' }}>{phase.title}</h4>
            <p style={{ color: 'var(--muted)', lineHeight: '1.4', fontSize: '0.8rem' }}>{phase.desc}</p>
          </div>
        ))}
      </div>
    </Section>
  )
}
