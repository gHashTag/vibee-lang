"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function BitNetProofSection() {
  const { t } = useI18n()
  const s = t.bitnetProof

  if (!s) return null

  return (
    <Section id="bitnet-proof">
      <div className="radial-glow" style={{ opacity: 0.15 }} />
      
      {/* Header */}
      <div className="tight fade">
        <div className="badge" style={{ marginBottom: '1.5rem' }}>{s.badge}</div>
        <h2 dangerouslySetInnerHTML={{ __html: s.title }} style={{ fontSize: 'clamp(2.5rem, 6vw, 4rem)', marginBottom: '1.5rem', lineHeight: 1.1 }} />
        <p style={{ maxWidth: '800px', margin: '0 auto 3rem', fontSize: '1.2rem', opacity: 0.9, lineHeight: 1.6, color: '#fff' }}>
          {s.sub}
        </p>
      </div>

      {/* Key Metrics Grid */}
      <div className="grid fade" style={{ 
        gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', 
        gap: '1.5rem', 
        maxWidth: '1200px', 
        margin: '0 auto 4rem' 
      }}>
        {s.metrics?.map((metric: { value: string; label: string; source: string }, i: number) => (
          <div key={i} className="premium-card" style={{ 
            textAlign: 'center', 
            padding: '1.5rem',
            background: 'linear-gradient(135deg, rgba(0,255,136,0.05) 0%, rgba(0,136,255,0.05) 100%)',
            border: '1px solid rgba(0,255,136,0.2)'
          }}>
            <div style={{ 
              fontSize: '2.5rem', 
              fontWeight: 700, 
              color: 'var(--accent)', 
              marginBottom: '0.5rem',
              textShadow: '0 0 20px rgba(0,255,136,0.3)'
            }}>{metric.value}</div>
            <div style={{ color: '#fff', fontSize: '0.9rem', marginBottom: '0.3rem' }}>{metric.label}</div>
            <div style={{ color: 'var(--muted)', fontSize: '0.75rem' }}>{metric.source}</div>
          </div>
        ))}
      </div>

      {/* Math Cards */}
      <div className="fade" style={{ marginBottom: '4rem' }}>
        <h3 style={{ textAlign: 'center', marginBottom: '2rem', color: '#fff' }}>{s.mathTitle}</h3>
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', 
          gap: '2rem',
          maxWidth: '1100px',
          margin: '0 auto'
        }}>
          {s.mathCards?.map((card: { title: string; formula: string; desc: string }, i: number) => (
            <div key={i} className="premium-card" style={{ 
              padding: '2rem',
              background: 'rgba(0,0,0,0.3)',
              border: '1px solid var(--border)'
            }}>
              <h4 style={{ color: 'var(--accent)', marginBottom: '1rem', fontSize: '1.1rem' }}>{card.title}</h4>
              <div style={{ 
                fontFamily: 'monospace', 
                fontSize: '1.3rem', 
                color: '#fff',
                background: 'rgba(0,255,136,0.1)',
                padding: '0.8rem 1rem',
                borderRadius: '8px',
                marginBottom: '1rem',
                textAlign: 'center'
              }}>{card.formula}</div>
              <p style={{ fontSize: '0.9rem', color: 'var(--muted)', margin: 0, lineHeight: 1.5 }}>{card.desc}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Comparison Table */}
      <div className="fade" style={{ marginBottom: '4rem' }}>
        <h3 style={{ textAlign: 'center', marginBottom: '2rem', color: '#fff' }}>{s.comparisonTitle}</h3>
        <div style={{ overflowX: 'auto', maxWidth: '900px', margin: '0 auto' }}>
          <table style={{ 
            width: '100%', 
            borderCollapse: 'collapse',
            background: 'rgba(0,0,0,0.3)',
            borderRadius: '12px',
            overflow: 'hidden'
          }}>
            <thead>
              <tr style={{ background: 'rgba(0,255,136,0.1)' }}>
                {s.comparisonHeaders?.map((header: string, i: number) => (
                  <th key={i} style={{ 
                    padding: '1rem', 
                    textAlign: 'left', 
                    color: 'var(--accent)',
                    fontWeight: 600,
                    fontSize: '0.9rem',
                    borderBottom: '1px solid var(--border)'
                  }}>{header}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {s.comparisonRows?.map((row: string[], i: number) => (
                <tr key={i} style={{ borderBottom: '1px solid var(--border)' }}>
                  {row.map((cell: string, j: number) => (
                    <td key={j} style={{ 
                      padding: '1rem', 
                      color: j === 3 ? 'var(--accent)' : '#fff',
                      fontWeight: j === 3 ? 700 : 400,
                      fontSize: '0.9rem'
                    }}>{cell}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ROI Section */}
      <div className="fade" style={{ 
        background: 'linear-gradient(135deg, rgba(0,255,136,0.1) 0%, rgba(0,136,255,0.1) 100%)',
        borderRadius: '16px',
        padding: '3rem',
        maxWidth: '900px',
        margin: '0 auto 4rem',
        border: '1px solid rgba(0,255,136,0.2)'
      }}>
        <h3 style={{ textAlign: 'center', marginBottom: '1rem', color: '#fff' }}>{s.roiTitle}</h3>
        <p style={{ textAlign: 'center', color: 'var(--muted)', marginBottom: '2rem' }}>{s.roiDesc}</p>
        <div style={{ display: 'flex', justifyContent: 'center', gap: '3rem', flexWrap: 'wrap' }}>
          {s.roiMetrics?.map((metric: { label: string; value: string }, i: number) => (
            <div key={i} style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '2rem', fontWeight: 700, color: 'var(--accent)' }}>{metric.value}</div>
              <div style={{ color: 'var(--muted)', fontSize: '0.9rem' }}>{metric.label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Sources */}
      <div className="fade" style={{ marginBottom: '3rem' }}>
        <h3 style={{ textAlign: 'center', marginBottom: '2rem', color: '#fff' }}>{s.sourcesTitle}</h3>
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', 
          gap: '1.5rem',
          maxWidth: '1000px',
          margin: '0 auto'
        }}>
          {s.sources?.map((source: { title: string; arxiv: string; desc: string }, i: number) => (
            <div key={i} style={{ 
              padding: '1.5rem',
              background: 'rgba(255,255,255,0.02)',
              borderRadius: '12px',
              border: '1px solid var(--border)'
            }}>
              <div style={{ fontWeight: 600, color: '#fff', marginBottom: '0.3rem' }}>{source.title}</div>
              <div style={{ 
                fontFamily: 'monospace', 
                fontSize: '0.8rem', 
                color: 'var(--accent)',
                marginBottom: '0.5rem'
              }}>{source.arxiv}</div>
              <div style={{ fontSize: '0.85rem', color: 'var(--muted)', lineHeight: 1.4 }}>{source.desc}</div>
            </div>
          ))}
        </div>
      </div>

      {/* CTA */}
      <div className="fade" style={{ textAlign: 'center' }}>
        <a 
          href={s.ctaUrl} 
          target="_blank" 
          rel="noopener noreferrer"
          className="btn"
          style={{ 
            display: 'inline-block',
            padding: '1rem 2.5rem',
            fontSize: '1.1rem'
          }}
        >
          {s.cta} →
        </a>
      </div>
    </Section>
  )
}
