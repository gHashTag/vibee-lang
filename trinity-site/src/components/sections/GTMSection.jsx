import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function GTMSection() {
  const { t } = useI18n()
  const gtm = t.gtm
  
  return (
    <Section id="gtm">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: gtm?.title }} />
      <div className="timeline fade">
        {gtm?.phases?.map((phase, i) => (
          <div key={i} className="tl-item glass">
            <div className="tl-phase">{phase.phase}</div>
            <div className="tl-content">
              <h4>{phase.title}</h4>
              <p>{phase.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </Section>
  )
}
