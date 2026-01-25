"use client";
import { useState } from 'react'
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function CalculatorSection() {
  const { t } = useI18n()
  const c = t.calculator
  const [nodes, setNodes] = useState(100)

  const binaryCost = nodes * 24 * 30 * 2 // $2/hour per node (Standard A100/H100)
  const trinityCost = binaryCost / 578.8 // Hyper-Singularity V5.0 Efficiency
  const savings = binaryCost - trinityCost

  return (
    <Section id="calculator">
      <div className="radial-glow" style={{ opacity: 0.15 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: c?.title }} />
      
      <div className="premium-card fade" style={{ width: '100%', maxWidth: '800px', margin: '4rem auto', padding: '3rem' }}>
        <div style={{ marginBottom: '3rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1rem', fontSize: '1rem', fontWeight: 500 }}>
            <span>{c?.nodes}</span>
            <span style={{ color: 'var(--accent)' }}>{nodes}</span>
          </div>
          <input 
            type="range" min="1" max="1000" value={nodes} 
            onChange={(e) => setNodes(parseInt(e.target.value))}
            style={{ width: '100%', accentColor: 'var(--accent)', cursor: 'pointer' }}
          />
        </div>

        <div className="grid" style={{ marginTop: 0, gap: '1.5rem' }}>
          <div style={{ padding: '1.5rem', border: '1px solid var(--border)', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--muted)', marginBottom: '0.5rem', textTransform: 'uppercase' }}>{c?.current}</div>
            <div style={{ fontSize: '1.5rem', color: '#ff453a' }}>${binaryCost.toLocaleString(undefined, { maximumFractionDigits: 2 })}</div>
          </div>
          <div style={{ padding: '1.5rem', border: '1px solid var(--border)', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--muted)', marginBottom: '0.5rem', textTransform: 'uppercase' }}>{c?.withTrinity}</div>
            <div style={{ fontSize: '1.5rem', color: 'var(--accent)' }}>${trinityCost.toLocaleString(undefined, { maximumFractionDigits: 2 })}</div>
          </div>
          <div style={{ gridColumn: '1 / -1', padding: '2rem', background: 'rgba(255, 255, 255, 0.02)', border: '1px solid var(--accent)', borderRadius: '8px', textAlign: 'center' }}>
            <div style={{ fontSize: '0.9rem', color: 'var(--accent)', marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{c?.savings}</div>
            <div style={{ fontSize: '3rem', fontWeight: 500, color: 'var(--text)' }}>${savings.toLocaleString(undefined, { maximumFractionDigits: 2 })}</div>
          </div>
        </div>
      </div>
    </Section>
  )
}
