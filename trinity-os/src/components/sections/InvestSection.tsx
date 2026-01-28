"use client";
import { motion } from 'framer-motion'
import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function InvestSection() {
  const { t } = useI18n()
  const inv = t.invest
  
  return (
    <Section id="invest">
      <div className="radial-glow" style={{ opacity: 0.4 }} />
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: inv.title }} />
      
      <div className="grid">
        {inv?.cards?.map((card: { value: string; label: string }, i: number) => (
          <motion.div 
            key={i} 
            className="premium-card" 
            initial={{ opacity: 0, scale: 0.8 }}
            whileInView={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.5, delay: i * 0.1, type: 'spring', stiffness: 100 }}
            viewport={{ once: true }}
            whileHover={{ scale: 1.05 }}
            style={{ textAlign: 'center' }}
          >
            <motion.h3 
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.1 + 0.2 }}
              viewport={{ once: true }}
              style={{ fontSize: '3rem', fontWeight: 500, marginBottom: '0.5rem' }}
            >
              {card.value}
            </motion.h3>
            <p style={{ fontSize: '0.9rem', color: 'var(--muted)' }}>{card.label}</p>
          </motion.div>
        ))}
      </div>
      
      <p className="fade" style={{ fontSize: '1.2rem', margin: '4rem 0', fontStyle: 'italic', maxWidth: '700px' }}>{inv?.closing}</p>
      
      <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(200px, 25vw, 300px), 1fr))', gap: '1.5rem' }}>
        <motion.div 
          className="premium-card" 
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          viewport={{ once: true }}
          whileHover={{ y: -5 }}
          style={{ textAlign: 'center', padding: 'clamp(1.5rem, 4vw, 2rem)', display: 'flex', flexDirection: 'column' }}
        >
          <h4 style={{ marginBottom: '1.5rem', fontWeight: 500, fontSize: 'clamp(1rem, 3vw, 1.2rem)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{inv.investorTitle}</h4>
          <div style={{ marginTop: 'auto' }}>
            <motion.a 
              href="https://www.xdao.app/42161/dao/0xf27a274cf9fa7079d9a194c149e35969d6362dec/modules/crowdfunding"
              target="_blank"
              rel="noopener noreferrer"
              className="btn" 
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ width: '100%', fontSize: '0.9rem', display: 'block' }}
            >
              {inv?.ctas?.investor}
            </motion.a>
          </div>
        </motion.div>
        <motion.div 
          className="premium-card" 
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          viewport={{ once: true }}
          whileHover={{ y: -5 }}
          style={{ textAlign: 'center', padding: 'clamp(1.5rem, 4vw, 2rem)', display: 'flex', flexDirection: 'column' }}
        >
          <h4 style={{ marginBottom: '1.5rem', fontWeight: 500, fontSize: 'clamp(1rem, 3vw, 1.2rem)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{inv.partnerTitle}</h4>
          <div style={{ marginTop: 'auto' }}>
            <motion.a 
              href="/play"
              className="btn secondary" 
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ width: '100%', fontSize: '0.9rem', display: 'block' }}
            >
              {inv?.ctas?.partner}
            </motion.a>
          </div>
        </motion.div>
        <motion.div 
          className="premium-card" 
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          viewport={{ once: true }}
          whileHover={{ y: -5 }}
          style={{ textAlign: 'center', padding: 'clamp(1.5rem, 4vw, 2rem)', display: 'flex', flexDirection: 'column' }}
        >
          <h4 style={{ marginBottom: '1.5rem', fontWeight: 500, fontSize: 'clamp(1rem, 3vw, 1.2rem)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{inv.talentTitle}</h4>
          <div style={{ marginTop: 'auto' }}>
            <motion.a 
              href="https://t.me/vibee_dev" 
              className="btn secondary" 
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              style={{ width: '100%', borderColor: '#229ED9', color: '#229ED9', fontSize: '0.9rem', display: 'block' }}
            >
              {inv?.ctas?.talent}
            </motion.a>
          </div>
        </motion.div>
      </div>

      <div className="fade" style={{ marginTop: '4rem', marginBottom: 'clamp(4rem, 15vh, 8rem)' }}>
        <a href={inv?.contact?.github} className="btn secondary" target="_blank" rel="noopener">{inv.ctaGithub}</a>
      </div>
    </Section>
  )
}
