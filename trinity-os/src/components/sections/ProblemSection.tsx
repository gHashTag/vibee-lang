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
      
      <div className="grid fade" style={{ textAlign: 'left', gap: '1.5rem' }}>
        <motion.div 
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.6 }}
          viewport={{ once: true }}
          className="premium-card"
        >
          <h4 style={{ color: '#ff453a', marginBottom: '1rem', fontSize: '1rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{p.binaryTitle}</h4>
          <p style={{ fontSize: '0.85rem', marginBottom: '1.5rem', lineHeight: '1.6' }}>{p.bitnetDesc.replace(/<[^>]*>?/gm, '')}</p>
          <div style={{ fontSize: '0.75rem', color: 'var(--muted)', fontFamily: 'monospace', background: 'rgba(0,0,0,0.2)', padding: '0.8rem', borderRadius: '4px' }}>
            {p.binaryFlow?.join(' → ')}
          </div>
        </motion.div>

        <motion.div 
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          viewport={{ once: true }}
          className="premium-card" style={{ borderLeft: '4px solid var(--accent)' }}
        >
          <h4 style={{ color: 'var(--accent)', marginBottom: '1rem', fontSize: '1rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{p.trinityTitle}</h4>
          <p style={{ fontSize: '0.85rem', marginBottom: '1.5rem', lineHeight: '1.6' }}>{p.trinityDesc}</p>
          <div style={{ fontSize: '0.75rem', color: 'var(--accent)', fontFamily: 'monospace', background: 'rgba(0,229,153,0.05)', padding: '0.8rem', borderRadius: '4px' }}>
            {p.trinityFlow?.join(' → ')}
          </div>
        </motion.div>
      </div>

      <DensityChart labels={p.density} />
      
      <div className="fade" style={{ marginTop: 'clamp(3rem, 10vw, 6rem)', padding: '0 1rem' }}>
        <p style={{ fontSize: 'clamp(1rem, 4vw, 1.3rem)', fontStyle: 'italic', maxWidth: '850px', lineHeight: '1.6', color: 'var(--text)' }}>
          "{p.quote.replace(/<[^>]*>?/gm, '')}"
        </p>
        <div style={{ fontSize: '0.85rem', marginTop: '1.5rem', color: 'var(--accent)', textTransform: 'uppercase', letterSpacing: '0.2em' }}>{p.quoteSrc}</div>
      </div>
    </Section>
  )
}
