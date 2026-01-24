import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function MarketSection() {
  const { t } = useI18n()
  const m = t.market
  
  return (
    <Section id="market">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: m.title }} />
      
      <div className="funnel fade">
        {m?.funnel?.map((item, i) => (
          <div key={i} className={`funnel-item funnel-${i}`}>
            <div className="funnel-value">{item.value}</div>
            <div className="funnel-label">{item.label}</div>
          </div>
        ))}
      </div>
      
      <div className="glass fade table-box">
        <h3>{m.compsTitle}</h3>
        <table>
          <thead>
            <tr>
              {m?.headers?.map((h, i) => <th key={i}>{h}</th>)}
            </tr>
          </thead>
          <tbody>
            {m?.rows?.map((row, i) => (
              <tr key={i} className={row[0] === 'TRINITY' ? 'highlight' : ''}>
                {row?.map((cell, j) => (
                  <td key={j} className={row[0] === 'TRINITY' ? 'hi' : ''}>{cell}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      
      <div className="gtm fade">
        <h3 dangerouslySetInnerHTML={{ __html: t.gtm.title }} />
        <div className="timeline">
          {t?.gtm?.phases?.map((phase, i) => (
            <div key={i} className="tl-item glass">
              <div className="tl-phase">{phase.phase}</div>
              <div className="tl-content">
                <h4>{phase.title}</h4>
                <p>{phase.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </Section>
  )
}
