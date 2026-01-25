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
      
      <div className="fade" style={{ marginTop: '3rem', width: '100%', maxWidth: '900px', overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
          <thead>
            <tr>
              {c.headers?.map((h: string, i: number) => (
                <th key={i} style={{ 
                  padding: '0.8rem', 
                  borderBottom: '1px solid var(--border)', 
                  color: 'var(--muted)', 
                  textAlign: 'center', 
                  fontWeight: '500',
                  fontSize: '0.75rem',
                  textTransform: 'uppercase',
                  letterSpacing: '0.1em'
                }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {c.rows?.map((row: { company: string; arch: string; val: string; ternary: boolean; open: boolean }, i: number) => (
              <tr key={i} style={{ background: row.company === 'TRINITY' ? 'rgba(0, 229, 153, 0.05)' : 'transparent' }}>
                <td style={{ padding: '0.8rem', borderBottom: '1px solid var(--border)', color: row.company === 'TRINITY' ? 'var(--accent)' : 'var(--text)', fontWeight: 500 }}>{row.company}</td>
                <td style={{ padding: '0.8rem', borderBottom: '1px solid var(--border)', color: 'var(--muted)' }}>{row.arch}</td>
                <td style={{ padding: '0.8rem', borderBottom: '1px solid var(--border)', color: 'var(--muted)' }}>{row.val}</td>
                <td style={{ padding: '0.8rem', borderBottom: '1px solid var(--border)', color: row.ternary ? 'var(--accent)' : '#ff453a', fontSize: '1rem', textAlign: 'center' }}>{row.ternary ? '✓' : '✗'}</td>
                <td style={{ padding: '0.8rem', borderBottom: '1px solid var(--border)', color: row.open ? 'var(--accent)' : '#ff453a', fontSize: '1rem', textAlign: 'center' }}>{row.open ? '✓' : '✗'}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <p style={{ marginTop: '2rem', fontSize: '0.85rem', textAlign: 'center', color: 'var(--muted)' }} dangerouslySetInnerHTML={{ __html: c.note }} />
      </div>
    </Section>
  )
}
