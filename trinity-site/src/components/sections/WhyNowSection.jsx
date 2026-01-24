import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function WhyNowSection() {
  const { t } = useI18n()
  const wn = t.whynow
  const uc = t.usecases
  
  const icons = [
    // Why Now Icons
    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="4 7 4 4 20 4 20 7"></polyline><line x1="9" y1="20" x2="15" y2="20"></line><line x1="12" y1="4" x2="12" y2="20"></line></svg>, // BitNet (Text/Symbol)
    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"></path></svg>, // Energy
    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"></rect><line x1="12" y1="18" x2="12.01" y2="18"></line></svg> // Edge AI
  ]

  const useCaseIcons = [
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>,
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>,
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="2" y="2" width="20" height="8" rx="2" ry="2"></rect><rect x="2" y="14" width="20" height="8" rx="2" ry="2"></rect><line x1="6" y1="6" x2="6.01" y2="6"></line><line x1="6" y1="18" x2="6.01" y2="18"></line></svg>
  ]

  return (
    <Section id="whynow">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: wn?.title }} />
      <div className="why-now-grid fade">
        {wn?.cards?.map((card, i) => (
          <div key={i} className="premium-card fade" style={{ transitionDelay: `${i * 100}ms` }}>
            <div className="icon-box">{icons[i]}</div>
            <h3>{card.title}</h3>
            <p>{card.desc}</p>
          </div>
        ))}
      </div>

      <div className="use-cases fade" style={{ marginTop: '6rem' }}>
        <h2 className="text-center" dangerouslySetInnerHTML={{ __html: uc?.title }} style={{ marginBottom: '3rem' }} />
        <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '2.5rem' }}>
          {uc?.items?.map((item, i) => (
            <div key={i} className="premium-card fade" style={{ textAlign: 'left', alignItems: 'flex-start', transitionDelay: `${i * 100}ms` }}>
              <div className="icon-box" style={{ background: 'rgba(48,209,88,0.1)', color: 'var(--green)' }}>{useCaseIcons[i]}</div>
              <h4 style={{ fontSize: '1.4rem', marginBottom: '1rem' }}>{item.title}</h4>
              <p style={{ color: 'var(--muted)', lineHeight: '1.6' }}>{item.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </Section>
  )
}
