import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function TeamSection() {
  const { t } = useI18n()
  const tm = t.team
  
  return (
    <Section id="team">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: tm.title }} style={{ marginBottom: '4rem' }} />
      
      <div className="glass fade" style={{ maxWidth: '600px', padding: '60px', borderRadius: '32px', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        {tm?.photo ? (
          <img src={tm.photo} alt={tm.name} style={{ width: '140px', height: '140px', borderRadius: '50%', objectFit: 'cover', border: '0.5px solid rgba(255,255,255,0.2)', marginBottom: '24px', boxShadow: '0 10px 30px rgba(0,0,0,0.5)' }} />
        ) : (
          <div className="team-avatar" style={{ marginBottom: '24px' }}>DV</div>
        )}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', justifyContent: 'center', marginBottom: '8px' }}>
          <h3 style={{ fontSize: '2rem', margin: 0, fontWeight: 700 }}>{tm?.name}</h3>
          {tm?.linkedin && (
            <a href={tm.linkedin} target="_blank" rel="noopener" className="hi" style={{ display: 'flex' }}>
              <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M19 0h-14c-2.761 0-5 2.239-5 5v14c0 2.761 2.239 5 5 5h14c2.762 0 5-2.239 5-5v-14c0-2.761-2.238-5-5-5zm-11 19h-3v-11h3v11zm-1.5-12.268c-.966 0-1.75-.79-1.75-1.764s.784-1.764 1.75-1.764 1.75.79 1.75 1.764-.783 1.764-1.75 1.764zm13.5 12.268h-3v-5.604c0-3.368-4-3.113-4 0v5.604h-3v-11h3v1.765c1.396-2.586 7-2.777 7 2.476v6.759z"/></svg>
            </a>
          )}
        </div>
        <p className="role" style={{ fontSize: '1.1rem', color: 'var(--accent)', fontWeight: 500, marginBottom: '2rem' }}>{tm?.role}</p>
        <ul style={{ listStyle: 'none', padding: 0, textAlign: 'left', width: '100%' }}>
          {tm?.exp?.map((item, i) => (
            <li key={i} style={{ padding: '8px 0', color: 'var(--muted)', fontSize: '0.95rem', display: 'flex', gap: '10px' }}>
              <span style={{ color: 'var(--green)' }}>✓</span> {item}
            </li>
          ))}
        </ul>
        <p className="sub fade hiring" style={{ marginTop: '2.5rem', fontWeight: 600 }}>{tm.hiring}</p>
      </div>
    </Section>
  )
}
