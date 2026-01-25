"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'
import ComparisonChart from '../charts/ComparisonChart'

export default function BenchmarksSection() {
  const { t } = useI18n()
  const b = t.benchmarks

  if (!b) return null

  return (
    <Section id="benchmarks">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: b.title }} />
        <p>{b.sub}</p>
      </div>
      
      <div className="grid fade" style={{ marginTop: '3rem', marginBottom: '4rem' }}>
        {b.metrics?.map((item: { value: string; label: string; desc: string }, i: number) => (
          <div 
            key={i} 
            className={`premium-card anim-fade-in-scale anim-delay-${i + 1}`}
            style={{ textAlign: 'center' }}
          >
            <div style={{ fontSize: '2.5rem', fontWeight: 500, color: i === 0 ? 'var(--accent)' : 'var(--text)', marginBottom: '0.5rem' }}>{item.value}</div>
            <div style={{ fontSize: '0.9rem', fontWeight: 500, color: 'var(--text)', marginBottom: '0.3rem' }}>{item.label}</div>
            <div style={{ fontSize: '0.8rem', color: 'var(--muted)' }}>{item.desc}</div>
          </div>
        ))}
      </div>

      <ComparisonChart 
        data={b.comparison?.rows || []} 
        title={t.charts?.comparisonTitle} 
        note={t.charts?.comparisonNote} 
      />

      <div className="fade" style={{ textAlign: 'center', marginTop: '3rem' }}>
        <a 
          href={b.url || "https://github.com/gHashTag/vibee-lang"} 
          target="_blank" 
          rel="noopener noreferrer"
          style={{
            display: 'inline-block',
            padding: '0.8rem 2rem',
            border: '1px solid var(--accent)',
            borderRadius: '4px',
            color: 'var(--accent)',
            textDecoration: 'none',
            fontSize: '0.9rem',
            transition: 'all 0.2s ease',
            background: 'rgba(0, 229, 153, 0.05)'
          }}
          onMouseOver={(e) => e.currentTarget.style.background = 'rgba(0, 229, 153, 0.1)'}
          onMouseOut={(e) => e.currentTarget.style.background = 'rgba(0, 229, 153, 0.05)'}
        >
          {b.verifyLink || "Verify on GitHub"}
        </a>
      </div>
    </Section>
  )
}
