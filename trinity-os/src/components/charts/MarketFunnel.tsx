"use client";
import { motion } from "framer-motion";

interface FunnelItem {
  value: string;
  label: string;
}

export default function MarketFunnel({ items }: { items: FunnelItem[] }) {
  return (
    <div style={{ 
      display: 'grid', 
      gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(200px, 28vw, 320px), 1fr))', 
      gap: '1.5rem', 
      width: '100%', 
      maxWidth: '1000px', 
      margin: '2rem auto', 
      padding: '0 1rem' 
    }}>
      {items.map((item, i) => {
        return (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, delay: i * 0.2 }}
            className="premium-card"
            style={{ 
              minHeight: '180px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              background: `linear-gradient(180deg, rgba(0, 229, 153, ${0.05 + (items.length - i) * 0.03}) 0%, rgba(0, 0, 0, 0.02) 100%)`,
              border: '1px solid var(--border)',
              position: 'relative',
              textAlign: 'center',
              padding: '1.5rem'
            }}
          >
             <div style={{ fontSize: 'clamp(2rem, 8vw, 3.5rem)', fontWeight: 600, color: i === 2 ? 'var(--accent)' : 'var(--text)', lineHeight: 1, marginBottom: '0.5rem' }}>{item.value}</div>
             <div style={{ fontSize: '0.7rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{item.label?.split('—')[0]}</div>
             <div style={{ fontSize: '0.85rem', color: 'var(--text)', marginTop: '0.3rem', fontWeight: 500 }}>{item.label?.split('—')[1]}</div>
          </motion.div>
        )
      })}
    </div>
  )
}
