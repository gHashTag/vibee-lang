import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function CompetitionSection() {
  const { t } = useI18n()
  const c = t.competition
  
  return (
    <Section id="competition">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: c.title }} />
      
      <div className="glass fade table-box">
        <table>
          <thead>
            <tr>
              {c?.headers?.map((h, i) => <th key={i}>{h}</th>)}
            </tr>
          </thead>
          <tbody>
            {c?.rows?.map((row, i) => (
              <tr key={i} className={row.company === 'TRINITY' ? 'highlight' : ''}>
                <td className={row.company === 'TRINITY' ? 'hi' : ''}>{row.company}</td>
                <td className={row.company === 'TRINITY' ? 'hi' : ''}>{row.arch}</td>
                <td>{row.val}</td>
                <td className={row.ternary ? 'hi' : 'red'}>{row.ternary ? '✓' : '✗'}</td>
                <td className={row.open ? 'hi' : 'red'}>{row.open ? '✓' : '✗'}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <p className="note" dangerouslySetInnerHTML={{ __html: c.note }} />
      </div>
    </Section>
  )
}
