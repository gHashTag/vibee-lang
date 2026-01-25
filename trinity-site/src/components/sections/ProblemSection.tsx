"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function ProblemSection() {
  const { t } = useI18n()
  const p = t.problem
  
  return (
    <Section id="problem">
      <div className="radial-glow" style={{ opacity: 0.5 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: p.title }} />
      <p className="fade" style={{ marginBottom: '4rem' }}>{p.sub}</p>
      
      <div className="grid fade" style={{ textAlign: 'left' }}>
        <div className="premium-card">
          <h4 style={{ color: '#ff453a', marginBottom: '1rem' }}>{p.binaryTitle}</h4>
          <p style={{ fontSize: '0.9rem', marginBottom: '1.5rem' }}>{p.bitnetDesc.replace(/<[^>]*>?/gm, '')}</p>
          <div style={{ fontSize: '0.85rem', color: 'var(--muted)', fontFamily: 'monospace' }}>
            {p.binaryFlow?.join(' → ')}
          </div>
        </div>

        <div className="premium-card" style={{ borderLeft: '4px solid var(--accent)' }}>
          <h4 style={{ color: 'var(--accent)', marginBottom: '1rem' }}>{p.trinityTitle}</h4>
          <p style={{ fontSize: '0.9rem', marginBottom: '1.5rem' }}>Native SU(3) core removes 99.8% waste and provides 100x faster inference.</p>
          <div style={{ fontSize: '0.85rem', color: 'var(--accent)', fontFamily: 'monospace' }}>
            {p.trinityFlow?.join(' → ')}
          </div>
        </div>
      </div>
      
      <p className="fade" style={{ marginTop: '4rem', fontSize: '1.2rem', fontStyle: 'italic', maxWidth: '800px' }}>
        "{p.quote.replace(/<[^>]*>?/gm, '')}"
        <span style={{ display: 'block', fontSize: '0.9rem', marginTop: '1rem', color: 'var(--accent)' }}>{p.quoteSrc}</span>
      </p>
    </Section>
  )
}
