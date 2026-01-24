import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function RoadmapSection() {
  const { t } = useI18n()
  const r = t.roadmap
  
  return (
    <Section id="roadmap">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: r?.title }} style={{ marginBottom: '3rem' }} />
      <div className="grid fade" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '2rem' }}>
        {r?.milestones?.map((m, i) => (
          <div key={i} className="premium-card fade" style={{ transitionDelay: `${i * 100}ms`, textAlign: 'left', alignItems: 'flex-start' }}>
            <div className="tag" style={{ fontSize: '12px', marginBottom: '1rem', color: 'var(--green)' }}>{m.date}</div>
            <h4 style={{ fontSize: '1.5rem', marginBottom: '1rem' }}>{m.title}</h4>
            <p style={{ color: 'var(--muted)', lineHeight: '1.6' }}>{m.desc}</p>
          </div>
        ))}
      </div>
    </Section>
  )
}
