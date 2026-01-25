"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'
import DensityChart from '../charts/DensityChart'

export default function ProblemSection() {
  const { t } = useI18n()
  const p = t.problem
  
  return (
    <Section id="problem">
      <div className="radial-glow" style={{ opacity: 0.5 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: p.title }} />
      <p className="fade" style={{ marginBottom: 'clamp(2rem, 6vw, 4rem)' }}>{p.sub}</p>
      
      <div className="grid fade" style={{ textAlign: 'left', gap: '1.2rem', alignItems: 'stretch' }}>
        <div className="premium-card anim-fade-in-up">
          <h4 style={{ color: '#ff453a', marginBottom: '0.8rem', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.15em' }}>{p.binaryTitle}</h4>
          <p style={{ fontSize: '0.85rem', marginBottom: '1.2rem', lineHeight: '1.6', opacity: 0.8 }}>{p.bitnetDesc.replace(/<[^>]*>?/gm, '')}</p>
          <div style={{ fontSize: '0.7rem', color: 'rgba(255,69,58,0.6)', fontFamily: 'monospace', background: 'rgba(255,69,58,0.05)', padding: '0.8rem', borderRadius: '6px', border: '1px solid rgba(255,69,58,0.1)' }}>
            {p.binaryFlow?.join(' → ')}
          </div>
        </div>

        <div className="premium-card anim-fade-in-up anim-delay-1" style={{ borderLeft: '3px solid var(--accent)' }}>
          <h4 style={{ color: 'var(--accent)', marginBottom: '0.8rem', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.15em' }}>{p.trinityTitle}</h4>
          <p style={{ fontSize: '0.85rem', marginBottom: '1.2rem', lineHeight: '1.6' }}>{p.trinityDesc}</p>
          <div style={{ fontSize: '0.7rem', color: 'var(--accent)', fontFamily: 'monospace', background: 'rgba(0,229,153,0.05)', padding: '0.8rem', borderRadius: '6px', border: '1px solid rgba(0,229,153,0.1)' }}>
            {p.trinityFlow?.join(' → ')}
          </div>
        </div>
      </div>

      <DensityChart labels={p.density} />
      
      <div className="fade" style={{ marginTop: 'clamp(3rem, 10vw, 6rem)', padding: '0 1rem' }}>
        <p style={{ fontSize: 'clamp(1rem, 4vw, 1.3rem)', fontStyle: 'italic', maxWidth: '850px', lineHeight: '1.6', color: 'var(--text)' }}>
          "{p.quote.replace(/<[^>]*>?/gm, '')}"
        </p>
        <div style={{ fontSize: '0.85rem', marginTop: '1.5rem', color: 'var(--accent)', textTransform: 'uppercase', letterSpacing: '0.2em' }}>{p.quoteSrc}</div>
      </div>
    </Section>
  )
}
