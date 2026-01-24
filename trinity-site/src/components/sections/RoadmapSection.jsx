import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function RoadmapSection() {
  const { t } = useI18n()
  const r = t.roadmap
  
  return (
    <Section id="roadmap">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: r?.title }} />
      <div className="timeline fade">
        {r?.milestones?.map((m, i) => (
          <div key={i} className="tl-item glass">
            <div className="tl-phase">{m.date}</div>
            <div className="tl-content">
              <h4>{m.title}</h4>
              <p>{m.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </Section>
  )
}
