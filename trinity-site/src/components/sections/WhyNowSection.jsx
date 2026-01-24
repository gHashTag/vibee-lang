import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function WhyNowSection() {
  const { t } = useI18n()
  const wn = t.whynow
  const uc = t.usecases
  
  return (
    <Section id="whynow">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: wn?.title }} />
      <div className="grid fade">
        {wn?.cards?.map((card, i) => (
          <div key={i} className="card glass">
            <h3>{card.title}</h3>
            <p>{card.desc}</p>
          </div>
        ))}
      </div>

      <div className="use-cases fade" style={{ marginTop: '4rem' }}>
        <h3 className="text-center" dangerouslySetInnerHTML={{ __html: uc?.title }} />
        <div className="grid">
          {uc?.items?.map((item, i) => (
            <div key={i} className="glass" style={{ padding: '1.5rem', borderRadius: '1rem' }}>
              <h4>{item.title}</h4>
              <p>{item.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </Section>
  )
}
