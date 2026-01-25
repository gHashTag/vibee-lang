"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function MiningSolutionSection() {
  const { t } = useI18n()
  const m = t.mining

  if (!m) return null

  return (
    <Section id="mining">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: m.title }} />
        <p>{m.sub}</p>
      </div>

      <div className="fade" style={{ marginTop: '3rem', width: '100%', maxWidth: '1000px' }}>
        <div style={{ 
          overflowX: 'auto', 
          WebkitOverflowScrolling: 'touch', 
          border: '1px solid var(--border)', 
          borderRadius: '12px', 
          background: 'rgba(255,255,255,0.02)',
          margin: '0 -10px'
        }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 'clamp(0.65rem, 2.5vw, 0.85rem)', minWidth: '600px' }}>
            <thead>
              <tr>
                {m.headers?.map((h: string, i: number) => (
                  <th key={i} style={{ 
                    padding: '1rem 0.8rem', 
                    borderBottom: '1px solid var(--border)', 
                    color: 'var(--muted)', 
                    textAlign: 'left', 
                    fontWeight: '600',
                    fontSize: '0.7rem',
                    textTransform: 'uppercase',
                    letterSpacing: '0.1em'
                  }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {m.rows?.map((row: any, i: number) => (
                <tr key={i} className="hover-pulse">
                  <td style={{ padding: '1.2rem 0.8rem', borderBottom: '1px solid var(--border)', fontWeight: 600, color: 'var(--text)', width: '20%' }}>
                    {row.barrier}
                    <div style={{ fontSize: '0.6rem', color: 'var(--accent)', opacity: 0.6, marginTop: '0.3rem', fontWeight: 500 }}>Source: {row.source}</div>
                  </td>
                  <td style={{ padding: '1.2rem 0.8rem', borderBottom: '1px solid var(--border)', color: 'var(--muted)', width: '35%' }}>
                    {row.impact}
                  </td>
                  <td style={{ 
                    padding: '1.2rem 0.8rem', 
                    borderBottom: '1px solid var(--border)', 
                    color: 'var(--accent)', 
                    background: 'rgba(0, 229, 153, 0.03)',
                    fontWeight: 500,
                    lineHeight: 1.4
                  }}>
                    {row.solution}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="fade" style={{ marginTop: '3rem', opacity: 0.6, fontSize: '0.8rem', fontStyle: 'italic' }}>
        * Trinity SU(3) Core transforms mining from a commodity game to a structural architectural advantage.
      </div>
    </Section>
  )
}
