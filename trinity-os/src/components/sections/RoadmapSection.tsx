"use client";
import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function RoadmapSection() {
  const { t } = useI18n()
  const r = t.roadmap
  
  return (
    <Section id="roadmap">
      <div className="radial-glow" style={{ opacity: 0.2 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: r?.title }} />
      
      <div className="grid" style={{ textAlign: 'left' }}>
        {r?.milestones?.map((m: { date: string; title: string; desc: string }, i: number) => (
          <motion.div 
            key={i} 
            className="premium-card"
            initial={{ opacity: 0, y: 30, scale: 0.95 }}
            whileInView={{ opacity: 1, y: 0, scale: 1 }}
            transition={{ duration: 0.5, delay: i * 0.15 }}
            viewport={{ once: true }}
            whileHover={{ y: -5, boxShadow: '0 10px 40px rgba(0, 229, 153, 0.15)' }}
          >
            <motion.div 
              initial={{ width: 0 }}
              whileInView={{ width: '40px' }}
              transition={{ duration: 0.8, delay: i * 0.15 + 0.3 }}
              viewport={{ once: true }}
              style={{ height: '2px', background: 'var(--accent)', marginBottom: '1rem' }}
            />
            <div style={{ fontSize: '0.8rem', color: 'var(--accent)', fontWeight: 500, marginBottom: '1rem', letterSpacing: '0.1em' }}>{m.date}</div>
            <h4 style={{ fontSize: '1.3rem', marginBottom: '1rem', fontWeight: 500 }}>{m.title}</h4>
            <p style={{ margin: 0, fontSize: '0.9rem' }}>{m.desc}</p>
          </motion.div>
        ))}
      </div>
    </Section>
  )
}
