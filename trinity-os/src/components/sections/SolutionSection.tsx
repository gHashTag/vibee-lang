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
      
      <div className="fade" style={{ display: 'flex', alignItems: 'center', gap: 'clamp(2rem, 8vw, 4rem)', margin: '4rem 0', flexWrap: 'wrap', justifyContent: 'center' }}>
        <div style={{ width: 'clamp(200px, 30vw, 250px)', height: 'clamp(200px, 30vw, 250px)', flexShrink: 0 }}>
          <svg viewBox="0 0 100 100" style={{ filter: 'drop-shadow(0 0 10px rgba(0, 229, 153, 0.2))' }}>
            <circle cx="50" cy="50" r="45" fill="none" stroke="var(--border)" strokeWidth="0.5" />
            <motion.circle 
              cx="50" cy="50" r="45" fill="none" stroke="var(--accent)" strokeWidth="3" 
              strokeDasharray="283"
              initial={{ pathLength: 0, rotate: -90 }}
              whileInView={{ pathLength: 1.585/3 }} // Illustrative of density ratio
              viewport={{ once: true }}
              transition={{ duration: 2, ease: "easeOut" }}
              strokeLinecap="round" 
            />
            <motion.text 
               x="50" y="42" textAnchor="middle" fill="var(--text)" fontSize="8" fontWeight="400" opacity="0.6"
               initial={{ opacity: 0, y: 35 }}
               whileInView={{ opacity: 0.6, y: 42 }}
               transition={{ delay: 0.5 }}
            >
              log₂(3)
            </motion.text>
            <motion.text 
               x="50" y="62" textAnchor="middle" fill="var(--accent)" fontSize="18" fontWeight="600"
               initial={{ opacity: 0, scale: 0.8 }}
               whileInView={{ opacity: 1, scale: 1 }}
               transition={{ delay: 0.8, type: 'spring' }}
            >
              1.585
            </motion.text>
          </svg>
        </div>
        <div style={{ textAlign: 'left' }}>
          {s.legend?.map((item: string, i: number) => (
            <motion.div 
               key={i} 
               initial={{ opacity: 0, x: -10 }}
               whileInView={{ opacity: 1, x: 0 }}
               transition={{ delay: 1 + i * 0.1 }}
               style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '0.8rem' }}
            >
              <motion.div 
                animate={{ scale: [1, 1.2, 1] }}
                transition={{ repeat: Infinity, duration: 2, delay: i * 0.5 }}
                style={{ width: '8px', height: '8px', borderRadius: '50%', background: i === 0 ? 'var(--accent)' : 'var(--border)' }} 
              />
              <span style={{ fontSize: '0.9rem', color: i === 0 ? 'var(--text)' : 'var(--muted)' }}>{item}</span>
            </motion.div>
          ))}
        </div>
      </div>
      
      <div className="grid-row fade">
        {s.cards?.map((card: { value: string; label: string; color: string }, i: number) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ delay: 1.5 + i * 0.1 }}
            style={{ flex: 1, minWidth: '140px' }}
          >
            <MetricCard value={card.value} label={card.label} color={card.color as any} />
          </motion.div>
        ))}
      </div>
    </Section>
  )
}
