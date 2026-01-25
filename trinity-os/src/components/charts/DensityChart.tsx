"use client";
import { motion } from "framer-motion";

export default function DensityChart({ labels }: { labels?: { title: string, bit: string, trit: string, efficiency: string } }) {
  const l = labels || { title: "Information Density", bit: "Binary Bit", trit: "Ternary Trit", efficiency: "+58% Density" };

  return (
    <div className="premium-card fade" style={{ width: '100%', maxWidth: '600px', margin: '2rem auto', padding: 'clamp(1rem, 5vw, 2rem)' }}>
      <h3 style={{ textAlign: 'center', marginBottom: '2rem', fontSize: '1.2rem' }}>{l.title}</h3>
      
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'center', gap: 'clamp(0.5rem, 5vw, 2rem)', height: '180px' }}>
        {/* Bit */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '0.8rem', flex: 1 }}>
          <motion.div 
            initial={{ height: 0 }}
            whileInView={{ height: '80px' }}
            transition={{ duration: 1 }}
            style={{ 
              width: '100%',
              maxWidth: '70px',
              background: 'rgba(255, 255, 255, 0.1)', 
              border: '1px solid var(--border)',
              borderRadius: '6px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--muted)',
              fontSize: '0.8rem'
            }}
          >
            1.00
          </motion.div>
          <div style={{ fontSize: 'clamp(0.65rem, 2.2vw, 0.85rem)', color: 'var(--muted)', textAlign: 'center', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{l.bit}</div>
        </div>

        {/* Trit */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '0.8rem', flex: 1 }}>
          <motion.div 
            initial={{ height: 0 }}
            whileInView={{ height: '128px' }} // 1.58x relative to 80px
            transition={{ duration: 1, delay: 0.2 }}
            style={{ 
              width: '100%',
              maxWidth: '70px',
              background: 'rgba(0, 229, 153, 0.15)', 
              border: '2px solid var(--accent)',
              borderRadius: '6px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#FFFFFF',
              fontWeight: 600,
              position: 'relative',
              fontSize: '0.9rem',
              boxShadow: '0 0 20px rgba(0, 229, 153, 0.15)'
            }}
          >
            1.58
            <motion.div 
              initial={{ opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ delay: 1.2 }}
              style={{ 
                position: 'absolute', 
                top: '-25px', 
                whiteSpace: 'nowrap', 
                color: 'var(--accent)', 
                fontSize: 'min(0.75rem, 3vw)',
                fontWeight: 600,
                textShadow: '0 0 10px rgba(0,229,153,0.3)'
              }}
            >
              {l.efficiency}
            </motion.div>
          </motion.div>
          <div style={{ fontSize: 'clamp(0.65rem, 2.2vw, 0.85rem)', color: 'var(--accent)', fontWeight: 500, textAlign: 'center', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{l.trit}</div>
        </div>
      </div>
      
      <div style={{ textAlign: 'center', marginTop: '1.5rem', fontSize: '0.85rem', color: 'var(--muted)' }}>
        log₂(3) ≈ 1.58496 bits
      </div>
    </div>
  )
}
