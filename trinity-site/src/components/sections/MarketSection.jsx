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
    </Section>
  )
}
