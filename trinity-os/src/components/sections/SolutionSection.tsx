import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'
import MetricCard from '../MetricCard'

export default function SolutionSection() {
  const { t } = useI18n()
  const s = t.solution
  
  if (!s) return null

  return (
    <Section id="solution">
      <div className="radial-glow" style={{ opacity: 0.3 }} />
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: s.title }} />
      </div>
      
      <div className="fade" style={{ display: 'flex', alignItems: 'center', gap: 'clamp(2rem, 8vw, 6rem)', margin: '3rem 0', flexWrap: 'wrap', justifyContent: 'center' }}>
        <div style={{ width: 'clamp(180px, 25vw, 220px)', height: 'clamp(180px, 25vw, 220px)', flexShrink: 0 }}>
          <svg viewBox="0 0 100 100" style={{ filter: 'drop-shadow(0 0 15px rgba(0, 229, 153, 0.15))' }}>
            <circle cx="50" cy="50" r="45" fill="none" stroke="var(--border)" strokeWidth="0.5" />
            <motion.circle 
              cx="50" cy="50" r="45" fill="none" stroke="var(--accent)" strokeWidth="2.5" 
              strokeDasharray="283"
              initial={{ pathLength: 0, rotate: -90 }}
              whileInView={{ pathLength: 1.585/3 }} 
              viewport={{ once: true }}
              transition={{ duration: 2.5, ease: "easeInOut" }}
              strokeLinecap="round" 
            />
            <motion.text 
               x="50" y="38" textAnchor="middle" dominantBaseline="middle" fill="var(--text)" fontSize="6" fontWeight="400" opacity="0.4"
               initial={{ opacity: 0 }}
               whileInView={{ opacity: 0.4 }}
               transition={{ delay: 0.5 }}
            >
              log₂(3)
            </motion.text>
            <motion.text 
               x="50" y="58" textAnchor="middle" dominantBaseline="middle" fill="var(--accent)" fontSize="24" fontWeight="600"
               initial={{ opacity: 0, scale: 0.8 }}
               whileInView={{ opacity: 1, scale: 1 }}
               transition={{ delay: 1, type: 'spring', stiffness: 80 }}
            >
              1.58
            </motion.text>
          </svg>
        </div>
        <div style={{ textAlign: 'left', minWidth: '280px' }}>
          {s.legend?.map((item: string, i: number) => (
            <motion.div 
               key={i} 
               initial={{ opacity: 0, x: -15 }}
               whileInView={{ opacity: 1, x: 0 }}
               transition={{ delay: 1.2 + i * 0.1 }}
               style={{ display: 'flex', alignItems: 'center', gap: '0.8rem', marginBottom: '0.8rem' }}
            >
              <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: i === 0 ? 'var(--accent)' : 'var(--border)' }} />
              <span style={{ fontSize: '0.85rem', color: i === 0 ? 'var(--text)' : 'rgba(255,255,255,0.6)', letterSpacing: '0.02em' }}>{item}</span>
            </motion.div>
          ))}
        </div>
      </div>
      
      <div className="grid-row fade" style={{ gap: '1rem', alignItems: 'stretch' }}>
        {s.cards?.map((card: { value: string; label: string; color: string }, i: number) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 15 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ delay: 1.4 + i * 0.05 }}
            style={{ flex: '1 1 120px', maxWidth: '180px' }}
          >
            <MetricCard value={card.value} label={card.label} color={card.color as any} />
          </motion.div>
        ))}
      </div>
    </Section>
  )
}
