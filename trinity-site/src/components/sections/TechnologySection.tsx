"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function TechnologySection() {
  const { t } = useI18n()
  const tech = t.technology

  if (!tech) return null

  return (
    <Section id="technology">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: tech.title }} />
        <p>{tech.sub}</p>
      </div>
      
      <div className="fade" style={{ marginTop: '3rem', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '1.5rem' }}>
        <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap' }}>
          {tech.layers?.map((layer, i) => (
            <div key={i} style={{ 
              border: '1px solid var(--accent)', 
              borderRadius: '8px', 
              padding: '1.5rem 2rem', 
              textAlign: 'center',
              background: 'rgba(0, 229, 153, 0.05)'
            }}>
              <div style={{ fontSize: '0.9rem', fontWeight: '600', color: 'var(--text)' }}>{layer.title}</div>
              <div style={{ fontSize: '0.7rem', color: 'var(--muted)', marginTop: '0.3rem' }}>{layer.desc}</div>
            </div>
          ))}
        </div>
        
        <div style={{ color: 'var(--muted)', fontSize: '1.5rem' }}>↓</div>
        
        <div style={{ 
          border: '1px solid var(--border)', 
          borderRadius: '8px', 
          padding: '1rem 2.5rem', 
          background: 'rgba(255,255,255,0.02)'
        }}>
          <div style={{ fontSize: '0.85rem', fontWeight: '500', color: 'var(--accent)' }}>{tech.softwareStack}</div>
        </div>
      </div>

      <div className="fade" style={{ marginTop: '3rem', textAlign: 'left', maxWidth: '600px' }}>
        <h4 style={{ color: 'var(--accent)', marginBottom: '1rem', fontSize: '0.85rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>Key Innovations</h4>
        {tech.innovations?.map((item, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '0.8rem', marginBottom: '0.6rem' }}>
            <span style={{ color: 'var(--accent)' }}>•</span>
            <span style={{ fontSize: '0.9rem', color: 'var(--muted)' }}>{item}</span>
          </div>
        ))}
      </div>
    </Section>
  )
}
