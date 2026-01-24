import { useI18n } from '../../i18n/context'
import Section from '../Section'
import MetricCard from '../MetricCard'

export default function TractionSection() {
  const { t } = useI18n()
  const tr = t.traction
  
  return (
    <Section id="traction">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: tr.title }} />
      <p className="sub fade">{tr.sub}</p>
      
      <div className="glass fade tech-grid">
        <h3>{tr.techTitle}</h3>
        <div className="techs">
          {tr?.techs?.map((tech, i) => (
            <div key={i} className="tech-card">
              <h4>{tech.title}</h4>
              <p>{tech.desc}</p>
              <span className="tests">{tech.tests}</span>
            </div>
          ))}
        </div>
      </div>
      
      <div className="glass fade progress-box">
        {tr?.progress?.map((item, i) => (
          <div key={i} className="progress-item">
            <div className="progress-header">
              <span>{item.label}</span>
              <span className="hi">{item.value}</span>
            </div>
            <div className="progress-bar">
              <div className="progress-fill" style={{ width: i === 0 ? '100%' : i === 1 ? '80%' : '34%' }} />
            </div>
          </div>
        ))}
      </div>
      
      <div className="metrics-grid fade">
        {tr?.metrics?.map((m, i) => (
          <MetricCard key={i} value={m.value} label={m.label} color={m.color} />
        ))}
      </div>
    </Section>
  )
}
