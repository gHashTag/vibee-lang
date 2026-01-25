"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function WhyNowSection() {
  const { t } = useI18n()
  const wn = t.whynow
  const uc = t.usecases
  
  return (
    <Section id="whynow">
      <div className="radial-glow" style={{ opacity: 0.2 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: wn?.title }} />
      
      <div className="grid fade">
        {wn?.cards?.map((card: { title: string; desc: string }, i: number) => (
          <div key={i} className="premium-card">
            <h3 style={{ fontSize: '1.2rem', color: 'var(--accent)', marginBottom: '1rem' }}>{card.title}</h3>
            <p style={{ textAlign: 'left', margin: 0, fontSize: '0.9rem' }}>{card.desc}</p>
          </div>
        ))}
      </div>

      <div style={{ marginTop: '6rem', width: '100%' }}>
        <h2 className="fade" dangerouslySetInnerHTML={{ __html: uc?.title }} style={{ marginBottom: '3rem' }} />
        <div className="grid fade">
          {uc?.items?.map((item: { title: string; desc: string }, i: number) => (
            <div 
              key={i} 
              className={`premium-card anim-fade-in-up anim-delay-${i + 1}`}
            >
              <h4 style={{ fontSize: '1.2rem', marginBottom: '1rem', color: 'var(--text)' }}>{item.title}</h4>
              <p style={{ textAlign: 'left', margin: 0, fontSize: '0.9rem' }}>{item.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </Section>
  )
}
