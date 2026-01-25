"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function VisionSection() {
  const { t } = useI18n()
  const v = t.vision

  if (!v) return null

  return (
    <Section id="vision">
      <div className="radial-glow" style={{ opacity: 0.4 }} />
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: v.title }} />
        <p style={{ fontSize: '1.3rem', fontStyle: 'italic', color: 'var(--text)', marginTop: '2rem' }}>{v.quote}</p>
      </div>
      
      <div className="fade" style={{ marginTop: '3rem', display: 'flex', gap: '4rem', justifyContent: 'center', flexWrap: 'wrap', textAlign: 'left' }}>
        <div>
          <h4 style={{ color: 'var(--accent)', marginBottom: '1rem', fontSize: '0.85rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{v.goalsTitle}</h4>
          {v.goals?.map((g: string, i: number) => (
            <div key={i} style={{ fontSize: '0.9rem', color: 'var(--muted)', marginBottom: '0.5rem' }}>• {g}</div>
          ))}
        </div>
        <div>
          <h4 style={{ color: 'var(--accent)', marginBottom: '1rem', fontSize: '0.85rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{v.whyNowTitle}</h4>
          {v.whyNow?.map((w: string, i: number) => (
            <div key={i} style={{ fontSize: '0.9rem', color: 'var(--muted)', marginBottom: '0.5rem' }}>✓ {w}</div>
          ))}
        </div>
      </div>

      <div className="fade" style={{ marginTop: '3rem' }}>
        <p style={{ fontSize: '1.1rem', color: 'var(--accent)', fontWeight: '500' }}>φ² + 1/φ² = 3</p>
        <p style={{ fontSize: '0.9rem', color: 'var(--muted)', marginTop: '0.5rem' }}>{v.closing}</p>
      </div>
    </Section>
  )
}
