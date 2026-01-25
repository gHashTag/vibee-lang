"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function TeamSection() {
  const { t } = useI18n()
  const team = t.team
  
  return (
    <Section id="team">
      <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(191, 90, 242, 0.1) 0%, transparent 60%)' }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: team.title }} />
      
      <div className="premium-card fade" style={{ display: 'flex', gap: 'clamp(1.5rem, 5vw, 3rem)', maxWidth: '800px', margin: '4rem auto', alignItems: 'center', flexWrap: 'wrap', justifyContent: 'center' }}>
        <img src={team.photo} alt={team.name} style={{ width: 'clamp(100px, 15vw, 120px)', height: 'clamp(100px, 15vw, 120px)', borderRadius: '50%', border: '1px solid var(--border)' }} />
        <div style={{ textAlign: 'left', flex: '1 1 250px' }}>
          <h3 style={{ fontSize: 'clamp(1.5rem, 4vw, 1.8rem)', marginBottom: '0.2rem' }}>{team.name}</h3>
          <p style={{ color: 'var(--accent)', fontSize: '0.9rem', fontWeight: 500, marginBottom: '1.5rem' }}>{team.role}</p>
          <ul style={{ listStyle: 'none' }}>
            {team.exp?.map((line: string, i: number) => (
              <li key={i} style={{ fontSize: '0.85rem', color: 'var(--muted)', marginBottom: '0.5rem', display: 'flex', gap: '0.5rem' }}>
                <span style={{ color: 'var(--accent)' }}>•</span> {line}
              </li>
            ))}
          </ul>
          <a href={team.linkedin} target="_blank" rel="noopener" className="btn secondary" style={{ marginTop: '1.5rem', padding: '8px 20px', fontSize: '0.8rem', width: 'fit-content' }}>{team.linkedinLabel}</a>
        </div>
      </div>
      
      <p className="fade" style={{ color: 'var(--accent)', fontWeight: 500 }}>{team.hiring}</p>
    </Section>
  )
}
