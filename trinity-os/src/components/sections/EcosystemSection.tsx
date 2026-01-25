"use client";
import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function EcosystemSection() {
  const { t } = useI18n()
  const eco = t.ecosystem

  if (!eco) return null

  return (
    <Section id="ecosystem">
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: eco.title }} />
        <p style={{ marginBottom: '4rem' }}>{eco.sub}</p>
      </div>
      
      <div className="grid" style={{ 
        gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(140px, 45%, 300px), 1fr))', 
        gap: 'clamp(0.8rem, 2vw, 1.5rem)' 
      }}>
        {eco.items?.map((item: { title: string; desc: string }, i: number) => (
          <motion.div 
            key={i} 
            className="premium-card compact" 
            initial={{ opacity: 0, x: -20 }}
            whileInView={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.4, delay: i * 0.08 }}
            viewport={{ once: true }}
            whileHover={{ x: 5, borderLeftColor: 'var(--accent)' }}
            style={{ 
              textAlign: 'left', 
              border: 'none', 
              borderLeft: '1px solid var(--border)', 
              borderRadius: 0, 
              background: 'transparent', 
              padding: '0.8rem 1rem' 
            }}
          >
            <motion.div 
              className="card-dot" 
              initial={{ scale: 0 }}
              whileInView={{ scale: 1 }}
              transition={{ delay: i * 0.08 + 0.2, type: 'spring' }}
              viewport={{ once: true }}
              style={{ width: '5px', height: '5px', borderRadius: '50%', background: 'var(--accent)', marginBottom: '0.6rem' }} 
            />
            <h4 style={{ fontSize: '0.9rem', marginBottom: '0.3rem', color: 'var(--text)', fontWeight: 600 }}>{item.title}</h4>
            <p style={{ margin: 0, lineHeight: '1.3', fontSize: '0.75rem', opacity: 0.7 }}>{item.desc}</p>
          </motion.div>
        ))}
      </div>

      <div className="tight" style={{ marginTop: '6rem' }}>
        <motion.p 
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          transition={{ duration: 1 }}
          viewport={{ once: true }}
          style={{ fontStyle: 'italic', marginBottom: '2rem', color: 'var(--muted)', fontSize: '0.9rem' }}
        >
          "{eco.quote}"
        </motion.p>
        <motion.div 
          className="formula-box" 
          initial={{ opacity: 0, scale: 0.9 }}
          whileInView={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.5, type: 'spring' }}
          viewport={{ once: true }}
          whileHover={{ boxShadow: '0 0 30px rgba(0, 229, 153, 0.2)' }}
          style={{ fontSize: '1rem', padding: '1rem' }}
        >
          {eco.formula}
        </motion.div>
      </div>
    </Section>
  )
}
