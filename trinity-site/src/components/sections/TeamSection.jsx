import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function TeamSection() {
  const { t } = useI18n()
  const tm = t.team
  
  return (
    <Section id="team">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: tm.title }} />
      
      <div className="team-card glass fade">
        <div className="team-avatar">DV</div>
        <div className="team-info">
          <h3>{tm.name}</h3>
          <p className="role">{tm.role}</p>
          <ul>
            {tm.exp.map((item, i) => <li key={i}>{item}</li>)}
          </ul>
        </div>
      </div>
      
      <p className="sub fade hiring">{tm.hiring}</p>
    </Section>
  )
}
