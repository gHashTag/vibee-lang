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
        {cl.comparison?.map((item, i) => (
          <div key={i} className="premium-card" style={{ maxWidth: '400px', textAlign: 'center', borderColor: i === 1 ? 'var(--accent)' : 'var(--border)' }}>
            <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>{item.icon}</div>
            <h3 style={{ marginBottom: '1rem', color: i === 1 ? 'var(--accent)' : 'var(--text)' }}>{item.title}</h3>
            <p style={{ color: 'var(--muted)', fontSize: '0.95rem', lineHeight: '1.6' }}>{item.desc}</p>
          </div>
        ))}
      </div>

      <div className="fade" style={{ marginTop: '3rem', maxWidth: '600px', margin: '3rem auto 0' }}>
        <p style={{ fontSize: '1.1rem', fontStyle: 'italic', color: 'var(--text)', textAlign: 'center' }}>{cl.quote}</p>
      </div>
    </Section>
  )
}
