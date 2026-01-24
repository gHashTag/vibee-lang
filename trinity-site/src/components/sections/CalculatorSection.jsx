import { useState } from 'react'
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function CalculatorSection() {
  const { lang } = useI18n()
  const [nodes, setNodes] = useState(100)
  const [utilization, setUtilization] = useState(80)

  const binaryCost = nodes * 24 * 30 * 2 // $2/hour per node
  const trinityCost = binaryCost * 0.4
  const savings = binaryCost - trinityCost

  return (
    <Section id="calculator">
      <div className="glass fade" style={{ padding: '3rem', maxWidth: '800px', margin: '0 auto' }}>
        <h2 style={{ textAlign: 'center', marginBottom: '2rem' }}>
          {lang === 'ru' ? 'Калькулятор экономии' : 'Savings Calculator'}
        </h2>
        
        <div style={{ marginBottom: '2rem' }}>
          <label style={{ display: 'block', marginBottom: '1rem' }}>
            {lang === 'ru' ? 'Количество узлов (GPU):' : 'Number of Nodes (GPUs):'} {nodes}
          </label>
          <input 
            type="range" min="1" max="1000" value={nodes} 
            onChange={(e) => setNodes(parseInt(e.target.value))}
            style={{ width: '100%', accentColor: 'var(--accent)' }}
          />
        </div>

        <div className="results grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '2rem' }}>
          <div className="result-item">
            <span className="lbl">{lang === 'ru' ? 'Текущие затраты (Месяц)' : 'Current Monthly Cost'}</span>
            <div className="val red">${binaryCost.toLocaleString()}</div>
          </div>
          <div className="result-item">
            <span className="lbl">{lang === 'ru' ? 'С TRINITY (Месяц)' : 'With TRINITY Monthly'}</span>
            <div className="val green" style={{ color: 'var(--green)' }}>${trinityCost.toLocaleString()}</div>
          </div>
          <div className="result-item" style={{ gridColumn: '1 / -1', textAlign: 'center', background: 'rgba(255,255,255,0.05)', padding: '1rem', borderRadius: '1rem' }}>
            <span className="lbl">{lang === 'ru' ? 'Чистая экономия' : 'Net Savings'}</span>
            <div className="val hi" style={{ fontSize: '3rem' }}>${savings.toLocaleString()}</div>
          </div>
        </div>
      </div>
    </Section>
  )
}
