import Section from '../Section'
import { useI18n } from '../../i18n/context'

export default function InvestorProofSection() {
  const { t } = useI18n()
  const proof = t.invest?.investorProof || {}
  const cards = proof.cards || []

  return (
    <Section id="investor-proof">
      <div className="tight fade">
        <div className="badge" style={{ marginBottom: '1.5rem' }}>{proof.badge || 'INVESTOR PROOF-OF-CONCEPT'}</div>
        <h2 className="grad" style={{ fontSize: 'clamp(2.5rem, 6vw, 4rem)', marginBottom: '1.5rem', lineHeight: 1.1 }}>{proof.title || 'Hardware Truth Demo'}</h2>
        <p style={{ maxWidth: '900px', margin: '0 auto 4rem', fontSize: '1.2rem', opacity: 0.9, lineHeight: 1.6, color: '#fff' }}>
          {proof.desc || ''}
        </p>
      </div>

      <div className="grid fade" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '2rem', maxWidth: '1100px', margin: '0 auto', textAlign: 'left' }}>
        {cards.map((card: { title: string; desc: string }, index: number) => (
          <div key={index} className="premium-card" style={{ padding: '2rem', background: 'rgba(255,255,255,0.02)' }}>
            <h4 style={{ color: 'var(--accent)', marginBottom: '0.8rem', fontSize: '1.1rem' }}>{card.title}</h4>
            <p style={{ fontSize: '0.9rem', margin: 0, opacity: 0.8, lineHeight: 1.5 }}>{card.desc}</p>
          </div>
        ))}
      </div>
    </Section>
  )
}
