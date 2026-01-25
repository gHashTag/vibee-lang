"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'
import GrowthChart from '../charts/GrowthChart'

export default function FinancialsSection() {
  const { t } = useI18n()
  const f = t.financials

  if (!f) return null

  return (
    <Section id="financials">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: f.title }} />
      </div>
      
      <GrowthChart />

      <div className="fade" style={{ marginTop: '3rem', overflowX: 'auto', width: '100%' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
          <thead>
            <tr>
              {f.headers?.map((h: string, i: number) => (
                <th key={i} style={{ padding: '0.8rem', borderBottom: '1px solid var(--border)', color: 'var(--muted)', textAlign: 'left', fontWeight: '500' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {f.rows?.map((row: string[], i: number) => (
              <tr key={i}>
                {row.map((cell: string, j: number) => (
                  <td key={j} style={{ padding: '0.8rem', borderBottom: '1px solid var(--border)', color: j === 0 ? 'var(--accent)' : 'var(--text)' }}>{cell}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
        <p style={{ marginTop: '1.5rem', fontSize: '0.75rem', color: 'var(--muted)', textAlign: 'center' }}>{f.note}</p>
      </div>
    </Section>
  )
}
