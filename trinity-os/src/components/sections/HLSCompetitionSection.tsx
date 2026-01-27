"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function HLSCompetitionSection() {
  const { t } = useI18n()
  const c = t.hlsCompetition
  
  if (!c) return null

  return (
    <Section id="hls-competition">
      <div className="radial-glow" style={{ opacity: 0.3, background: 'radial-gradient(circle, rgba(255,165,0,0.15) 0%, transparent 70%)' }} />
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: c.title }} />
        <p style={{ color: 'var(--muted)', marginTop: '0.5rem', maxWidth: '600px', textAlign: 'center' }}>{c.sub}</p>
      </div>
      
      {/* Problem Statement */}
      {c.problemTitle && (
        <div className="fade" style={{
          marginTop: '2rem',
          background: 'rgba(255,69,58,0.08)',
          border: '1px solid rgba(255,69,58,0.3)',
          borderRadius: '12px',
          padding: '1.5rem 2rem',
          maxWidth: '700px',
          textAlign: 'center'
        }}>
          <h3 style={{ color: '#ff453a', marginBottom: '0.75rem', fontSize: '1.1rem' }}>{c.problemTitle}</h3>
          <p style={{ color: 'var(--muted)', fontSize: '0.9rem', lineHeight: 1.6 }}>{c.problemDesc}</p>
        </div>
      )}

      {/* Market Size Banner */}
      <div className="fade" style={{ 
        marginTop: '2rem', 
        display: 'flex', 
        justifyContent: 'center', 
        gap: '2rem',
        flexWrap: 'wrap'
      }}>
        <div style={{
          background: 'linear-gradient(135deg, rgba(255,165,0,0.1) 0%, rgba(255,100,0,0.05) 100%)',
          border: '1px solid rgba(255,165,0,0.3)',
          borderRadius: '16px',
          padding: '1.5rem 2.5rem',
          textAlign: 'center'
        }}>
          <div style={{ fontSize: '2.5rem', fontWeight: 700, color: '#FFA500' }}>{c.marketSize}</div>
          <div style={{ fontSize: '0.85rem', color: 'var(--muted)' }}>{c.marketGrowth}</div>
        </div>
      </div>

      {/* Competition Table */}
      <div className="fade" style={{ marginTop: '2.5rem', width: '100%', maxWidth: '1000px' }}>
        <div style={{ 
          overflowX: 'auto', 
          WebkitOverflowScrolling: 'touch', 
          border: '1px solid var(--border)', 
          borderRadius: '12px', 
          background: 'rgba(255,255,255,0.02)',
          margin: '0 -10px'
        }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 'clamp(0.65rem, 2.5vw, 0.85rem)', minWidth: '650px' }}>
            <thead>
              <tr>
                {c.headers?.map((h: string, i: number) => (
                  <th key={i} style={{ 
                    padding: '1rem 0.75rem', 
                    borderBottom: '1px solid var(--border)', 
                    color: 'var(--muted)', 
                    textAlign: 'center', 
                    fontWeight: '600',
                    fontSize: '0.7rem',
                    whiteSpace: 'nowrap',
                    textTransform: 'uppercase',
                    letterSpacing: '0.05em'
                  }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {c.rows?.map((row: { company: string; langs: string; price: string; lock: boolean; open: boolean }, i: number) => (
                <tr key={i} style={{ 
                  background: row.company === 'VIBEE Firebird' ? 'rgba(255, 165, 0, 0.08)' : 'transparent',
                  transition: 'background 0.2s'
                }}>
                  <td style={{ 
                    padding: '1rem 0.75rem', 
                    borderBottom: '1px solid var(--border)', 
                    color: row.company === 'VIBEE Firebird' ? '#FFA500' : 'var(--text)', 
                    fontWeight: row.company === 'VIBEE Firebird' ? 700 : 600, 
                    textAlign: 'center' 
                  }}>
                    {row.company === 'VIBEE Firebird' ? '🔥 ' + row.company : row.company}
                  </td>
                  <td style={{ 
                    padding: '1rem 0.75rem', 
                    borderBottom: '1px solid var(--border)', 
                    color: row.company === 'VIBEE Firebird' ? '#FFA500' : 'var(--muted)', 
                    textAlign: 'center',
                    fontWeight: row.company === 'VIBEE Firebird' ? 600 : 400
                  }}>{row.langs}</td>
                  <td style={{ 
                    padding: '1rem 0.75rem', 
                    borderBottom: '1px solid var(--border)', 
                    color: row.price === 'FREE' ? 'var(--accent)' : (row.price.includes('50K') ? '#ff453a' : 'var(--muted)'), 
                    textAlign: 'center',
                    fontWeight: row.price === 'FREE' ? 700 : 400
                  }}>{row.price}</td>
                  <td style={{ 
                    padding: '1rem 0.75rem', 
                    borderBottom: '1px solid var(--border)', 
                    color: row.lock ? '#ff453a' : 'var(--accent)', 
                    fontSize: '1.2rem', 
                    textAlign: 'center' 
                  }}>{row.lock ? '🔒' : '🔓'}</td>
                  <td style={{ 
                    padding: '1rem 0.75rem', 
                    borderBottom: '1px solid var(--border)', 
                    color: row.open ? 'var(--accent)' : '#ff453a', 
                    fontSize: '1.2rem', 
                    textAlign: 'center' 
                  }}>{row.open ? '✓' : '✗'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Advantages Grid */}
      <div className="fade" style={{ 
        marginTop: '3rem', 
        display: 'grid', 
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', 
        gap: '1.5rem',
        width: '100%',
        maxWidth: '1000px'
      }}>
        {c.advantages?.map((adv: { icon: string; title: string; desc: string }, i: number) => (
          <div key={i} style={{
            background: 'rgba(255,255,255,0.02)',
            border: '1px solid var(--border)',
            borderRadius: '12px',
            padding: '1.5rem',
            textAlign: 'center',
            transition: 'transform 0.2s, border-color 0.2s'
          }}>
            <div style={{ fontSize: '2rem', marginBottom: '0.75rem' }}>{adv.icon}</div>
            <div style={{ fontWeight: 600, color: 'var(--text)', marginBottom: '0.5rem' }}>{adv.title}</div>
            <div style={{ fontSize: '0.8rem', color: 'var(--muted)', lineHeight: 1.5 }}>{adv.desc}</div>
          </div>
        ))}
      </div>

      {/* Why It Matters */}
      {c.whyItMatters && (
        <div className="fade" style={{
          marginTop: '2.5rem',
          background: 'linear-gradient(135deg, rgba(0,229,153,0.08) 0%, rgba(0,150,100,0.05) 100%)',
          border: '1px solid rgba(0,229,153,0.3)',
          borderRadius: '12px',
          padding: '1.5rem 2rem',
          maxWidth: '700px',
          textAlign: 'center'
        }}>
          <h3 style={{ color: 'var(--accent)', marginBottom: '0.75rem', fontSize: '1.1rem' }}>{c.whyItMatters}</h3>
          <p style={{ color: 'var(--muted)', fontSize: '0.9rem', lineHeight: 1.6 }}>{c.whyItMattersDesc}</p>
        </div>
      )}

      {/* Note */}
      <p className="fade" style={{ 
        marginTop: '2rem', 
        fontSize: '1rem', 
        textAlign: 'center', 
        color: 'var(--text)',
        maxWidth: '700px',
        fontWeight: 500
      }} dangerouslySetInnerHTML={{ __html: c.note }} />

      {/* Supported Languages */}
      <div className="fade" style={{
        marginTop: '3rem',
        background: 'linear-gradient(135deg, rgba(255,165,0,0.05) 0%, rgba(0,229,153,0.05) 100%)',
        border: '1px solid rgba(255,165,0,0.2)',
        borderRadius: '16px',
        padding: '2rem',
        width: '100%',
        maxWidth: '900px'
      }}>
        <h3 style={{ textAlign: 'center', marginBottom: '1.5rem', color: '#FFA500' }}>
          33+ Supported Languages
        </h3>
        <div style={{
          display: 'flex',
          flexWrap: 'wrap',
          justifyContent: 'center',
          gap: '0.5rem'
        }}>
          {[
            'Python', 'JavaScript', 'TypeScript', 'Java', 'C', 'C++', 'C#', 'Zig',
            'Rust', 'Go', 'Swift', 'Kotlin', 'Ruby', 'PHP', 'Perl', 'Lua',
            'Julia', 'R', 'MATLAB', 'Scala', 'Elixir', 'Haskell', 'OCaml', 'F#',
            'Clojure', 'Erlang', 'Nim', 'Crystal', 'Verilog', 'VHDL', 'SystemVerilog', 'SystemC',
            'Chisel', '.999'
          ].map((lang, i) => (
            <span key={i} style={{
              background: lang === '.999' ? 'rgba(255,165,0,0.2)' : 'rgba(255,255,255,0.05)',
              border: `1px solid ${lang === '.999' ? 'rgba(255,165,0,0.5)' : 'var(--border)'}`,
              borderRadius: '6px',
              padding: '0.35rem 0.75rem',
              fontSize: '0.75rem',
              color: lang === '.999' ? '#FFA500' : 'var(--muted)',
              fontWeight: lang === '.999' ? 600 : 400
            }}>
              {lang}
            </span>
          ))}
        </div>
      </div>
    </Section>
  )
}
