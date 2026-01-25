"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function RoadmapSection() {
  const { t } = useI18n()
  const r = t.roadmap
  
  return (
    <Section id="roadmap">
      <div className="radial-glow" style={{ opacity: 0.2 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: r?.title }} />
      
      <div className="grid fade" style={{ textAlign: 'left' }}>
        {r?.milestones?.map((m, i) => (
          <div key={i} className="premium-card">
            <div style={{ fontSize: '0.8rem', color: 'var(--accent)', fontWeight: 500, marginBottom: '1rem', letterSpacing: '0.1em' }}>{m.date}</div>
            <h4 style={{ fontSize: '1.3rem', marginBottom: '1rem', fontWeight: 500 }}>{m.title}</h4>
            <p style={{ margin: 0, fontSize: '0.9rem' }}>{m.desc}</p>
          </div>
        ))}
      </div>
    </Section>
  )
}
