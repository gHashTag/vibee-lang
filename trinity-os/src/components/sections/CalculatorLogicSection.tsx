"use client";
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function CalculatorLogicSection() {
  const { t } = useI18n()
  const cl = t.calculatorLogic

  if (!cl) return null

  return (
    <Section id="calculator-logic">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: cl.title }} />
        <p>{cl.sub}</p>
      </div>
      
      <div className="fade" style={{ marginTop: '3rem', display: 'flex', gap: '2rem', flexWrap: 'wrap', justifyContent: 'center' }}>
        {cl.comparison?.map((item: { icon: string; title: string; desc: string }, i: number) => (
          <div key={i} className="premium-card" style={{ flex: '1 1 300px', maxWidth: '450px', textAlign: 'center', borderColor: i === 1 ? 'var(--accent)' : 'var(--border)', padding: 'clamp(1.5rem, 5vw, 2.5rem)' }}>
            <div style={{ fontSize: 'clamp(2.5rem, 8vw, 3.5rem)', marginBottom: '1rem' }}>{item.icon}</div>
            <h3 style={{ marginBottom: '1rem', color: i === 1 ? 'var(--accent)' : 'var(--text)', fontSize: 'clamp(1.2rem, 4vw, 1.5rem)' }}>{item.title}</h3>
            <p style={{ color: 'var(--muted)', fontSize: 'clamp(0.85rem, 2.5vw, 0.95rem)', lineHeight: '1.6' }}>{item.desc}</p>
          </div>
        ))}
      </div>

      <div className="fade" style={{ marginTop: '3rem', maxWidth: '600px', margin: '3rem auto 0' }}>
        <p style={{ fontSize: '1.1rem', fontStyle: 'italic', color: 'var(--text)', textAlign: 'center' }}>{cl.quote}</p>
      </div>
    </Section>
  )
}
