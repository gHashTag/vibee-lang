import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function BusinessModelSection() {
  const { t } = useI18n()
  const bm = t.businessModel

  if (!bm) return null

  return (
    <Section id="businessmodel">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: bm.title }} />
      </div>
      
      <div className="grid-row fade" style={{ marginTop: '3rem' }}>
        {bm.streams?.map((stream, i) => (
          <div key={i} className="premium-card compact" style={{ textAlign: 'left', background: 'rgba(255,255,255,0.02)' }}>
            <div style={{ fontSize: '1.5rem', color: 'var(--accent)', marginBottom: '0.4rem', fontWeight: '600' }}>{stream.percent}</div>
            <h4 style={{ marginBottom: '0.6rem', fontSize: '1rem' }}>{stream.title}</h4>
            <p style={{ color: 'var(--muted)', lineHeight: '1.4', fontSize: '0.75rem', margin: 0 }}>{stream.desc}</p>
          </div>
        ))}
      </div>
      
      <div className="tight fade" style={{ marginTop: '2rem' }}>
        <p style={{ fontSize: '0.85rem', color: 'var(--accent)', textAlign: 'center' }}>{bm.unitEcon}</p>
      </div>
    </Section>
  )
}
