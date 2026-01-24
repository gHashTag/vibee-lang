import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function TeamSection() {
  const { t } = useI18n()
  const tm = t.team
  
  return (
    <Section id="team">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: tm.title }} />
      
      <div className="team-card glass fade" style={{ display: 'flex', gap: '2rem', alignItems: 'center' }}>
        {tm?.photo ? (
          <img src={tm.photo} alt={tm.name} style={{ width: '120px', height: '120px', borderRadius: '50%', objectFit: 'cover', border: '2px solid var(--accent)' }} />
        ) : (
          <div className="team-avatar">DV</div>
        )}
        <div className="team-info">
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <h3 style={{ margin: 0 }}>{tm?.name}</h3>
            {tm?.linkedin && (
              <a href={tm.linkedin} target="_blank" rel="noopener" className="hi">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M19 0h-14c-2.761 0-5 2.239-5 5v14c0 2.761 2.239 5 5 5h14c2.762 0 5-2.239 5-5v-14c0-2.761-2.238-5-5-5zm-11 19h-3v-11h3v11zm-1.5-12.268c-.966 0-1.75-.79-1.75-1.764s.784-1.764 1.75-1.764 1.75.79 1.75 1.764-.783 1.764-1.75 1.764zm13.5 12.268h-3v-5.604c0-3.368-4-3.113-4 0v5.604h-3v-11h3v1.765c1.396-2.586 7-2.777 7 2.476v6.759z"/>
                </svg>
              </a>
            )}
          </div>
          <p className="role">{tm?.role}</p>
          <ul>
            {tm?.exp?.map((item, i) => <li key={i}>{item}</li>)}
          </ul>
        </div>
      </div>
      
      <p className="sub fade hiring">{tm.hiring}</p>
    </Section>
  )
}
