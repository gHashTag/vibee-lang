"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function CompetitionSection() {
  const { t } = useI18n()
  const c = t.competition
  
  if (!c) return null

  return (
    <Section id="competition">
      <div className="radial-glow" style={{ opacity: 0.2 }} />
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: c.title }} />
      </div>
      
      <div className="fade" style={{ marginTop: '3rem', width: '100%', maxWidth: '900px' }}>
        <div style={{ overflowX: 'auto', WebkitOverflowScrolling: 'touch', border: '1px solid var(--border)', borderRadius: '12px', background: 'rgba(255,255,255,0.02)' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 'clamp(0.7rem, 2vw, 0.85rem)', minWidth: '600px' }}>
            <thead>
              <tr>
                {c.headers?.map((h: string, i: number) => (
                  <th key={i} style={{ 
                    padding: '1rem', 
                    borderBottom: '1px solid var(--border)', 
                    color: 'var(--muted)', 
                    textAlign: 'center', 
                    fontWeight: '500',
                    fontSize: '0.7rem',
                    textTransform: 'uppercase',
                    letterSpacing: '0.1em'
                  }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {c.rows?.map((row: { company: string; arch: string; val: string; ternary: boolean; open: boolean }, i: number) => (
                <tr key={i} style={{ background: row.company === 'TRINITY' ? 'rgba(0, 229, 153, 0.05)' : 'transparent' }}>
                  <td style={{ padding: '1rem', borderBottom: '1px solid var(--border)', color: row.company === 'TRINITY' ? 'var(--accent)' : 'var(--text)', fontWeight: 500 }}>{row.company}</td>
                  <td style={{ padding: '1rem', borderBottom: '1px solid var(--border)', color: 'var(--muted)' }}>{row.arch}</td>
                  <td style={{ padding: '1rem', borderBottom: '1px solid var(--border)', color: 'var(--muted)' }}>{row.val}</td>
                  <td style={{ padding: '1rem', borderBottom: '1px solid var(--border)', color: row.ternary ? 'var(--accent)' : '#ff453a', fontSize: '1.2rem', textAlign: 'center' }}>{row.ternary ? '✓' : '✗'}</td>
                  <td style={{ padding: '1rem', borderBottom: '1px solid var(--border)', color: row.open ? 'var(--accent)' : '#ff453a', fontSize: '1.2rem', textAlign: 'center' }}>{row.open ? '✓' : '✗'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p style={{ marginTop: '2rem', fontSize: '0.85rem', textAlign: 'center', color: 'var(--muted)' }} dangerouslySetInnerHTML={{ __html: c.note }} />
      </div>
    </Section>
  )
}
