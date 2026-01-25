"use client";
import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'
import DensityChart from '../charts/DensityChart'

export default function ProblemSection() {
  const { t } = useI18n()
  const p = t.problem
  
  return (
    <Section id="problem">
      <div className="radial-glow" style={{ opacity: 0.5 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: p.title }} />
      <p className="fade" style={{ marginBottom: 'clamp(2rem, 6vw, 4rem)' }}>{p.sub}</p>
      
      <div className="grid fade" style={{ textAlign: 'left' }}>
        <motion.div 
          initial={{ opacity: 0, x: -30 }}
          whileInView={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.8 }}
          viewport={{ once: true }}
          className="premium-card"
        >
          <h4 style={{ color: '#ff453a', marginBottom: '1rem', fontSize: 'clamp(1rem, 3vw, 1.2rem)' }}>{p.binaryTitle}</h4>
          <p style={{ fontSize: 'clamp(0.8rem, 2.5vw, 0.9rem)', marginBottom: '1.5rem' }}>{p.bitnetDesc.replace(/<[^>]*>?/gm, '')}</p>
          <div style={{ fontSize: 'clamp(0.7rem, 2vw, 0.85rem)', color: 'var(--muted)', fontFamily: 'monospace' }}>
            {p.binaryFlow?.join(' → ')}
          </div>
        </motion.div>

        <motion.div 
          initial={{ opacity: 0, x: 30 }}
          whileInView={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          viewport={{ once: true }}
          className="premium-card" style={{ borderLeft: '4px solid var(--accent)' }}
        >
          <h4 style={{ color: 'var(--accent)', marginBottom: '1rem', fontSize: 'clamp(1rem, 3vw, 1.2rem)' }}>{p.trinityTitle}</h4>
          <p style={{ fontSize: 'clamp(0.8rem, 2.5vw, 0.9rem)', marginBottom: '1.5rem' }}>{p.trinityDesc}</p>
          <div style={{ fontSize: 'clamp(0.7rem, 2vw, 0.85rem)', color: 'var(--accent)', fontFamily: 'monospace' }}>
            {p.trinityFlow?.join(' → ')}
          </div>
        </motion.div>
      </div>

      <DensityChart labels={p.density} />
      
      <p className="fade" style={{ marginTop: '4rem', fontSize: '1.2rem', fontStyle: 'italic', maxWidth: '800px' }}>
        "{p.quote.replace(/<[^>]*>?/gm, '')}"
        <span style={{ display: 'block', fontSize: '0.9rem', marginTop: '1rem', color: 'var(--accent)' }}>{p.quoteSrc}</span>
      </p>
    </Section>
  )
}
