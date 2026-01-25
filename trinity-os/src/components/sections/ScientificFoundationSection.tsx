"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function ScientificFoundationSection() {
  const { t } = useI18n()
  const sf = t.scientificFoundation

  if (!sf) return null

  return (
    <Section id="scientific-foundation">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: sf.title }} />
        <p>{sf.sub}</p>
      </div>
      
      <div className="grid fade" style={{ 
        marginTop: '3rem', 
        marginBottom: '4rem', 
        gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(150px, 22vw, 240px), 1fr))',
        gap: '20px'
      }}>
        {sf.items?.map((item: { icon: string; value: string; label: string; desc: string }, i: number) => (
          <div key={i} className="premium-card" style={{ 
            textAlign: 'center', 
            aspectRatio: '1/1', 
            display: 'flex', 
            flexDirection: 'column', 
            justifyContent: 'center', 
            alignItems: 'center',
            padding: '1.5rem 1rem' 
          }}>
            <div style={{ fontSize: 'clamp(1.50rem, 4vw, 2.2rem)', marginBottom: '0.4rem' }}>{item.icon}</div>
            <div style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.8rem)', fontWeight: 700, color: 'var(--text)', marginBottom: '0.1rem', lineHeight: 1 }}>{item.value}</div>
            <div style={{ fontSize: '0.8rem', fontWeight: 600, color: 'var(--accent)', marginBottom: '0.4rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{item.label}</div>
            <div style={{ fontSize: '0.7rem', color: 'var(--muted)', lineHeight: '1.3', maxWidth: '100%' }}>{item.desc}</div>
          </div>
        ))}
      </div>

      <div className="premium-card fade" style={{ maxWidth: '800px', margin: '0 auto', textAlign: 'left' }}>
        <h3 style={{ fontSize: '1.2rem', marginBottom: '1.5rem', color: 'var(--text)', borderBottom: '1px solid var(--border)', paddingBottom: '1rem' }}>
          {sf.paperTitle}
        </h3>
        <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
          {sf.papers?.map((paper: string, i: number) => (
            <li key={i} style={{ marginBottom: '1rem', display: 'flex', alignItems: 'flex-start', gap: '0.8rem' }}>
              <span style={{ color: 'var(--accent)', fontSize: '1.2rem', lineHeight: '1' }}>•</span>
              <span style={{ color: 'var(--text)', fontSize: '1rem' }}>{paper}</span>
            </li>
          ))}
        </ul>
      </div>
    </Section>
  )
}
