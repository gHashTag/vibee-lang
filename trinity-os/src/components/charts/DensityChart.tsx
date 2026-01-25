"use client";
import { motion } from "framer-motion";

export default function DensityChart({ labels }: { labels?: { title: string, bit: string, trit: string, efficiency: string } }) {
  const l = labels || { title: "Information Density", bit: "Binary Bit", trit: "Ternary Trit", efficiency: "+58% Density" };

  return (
    <div className="premium-card fade" style={{ width: '100%', maxWidth: '600px', margin: '2rem auto', padding: '2rem' }}>
      <h3 style={{ textAlign: 'center', marginBottom: '2rem', fontSize: '1.2rem' }}>{l.title}</h3>
      
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'center', gap: '3rem', height: '200px' }}>
        {/* Bit */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '1rem' }}>
          <motion.div 
            initial={{ height: 0 }}
            whileInView={{ height: '100px' }}
            transition={{ duration: 1 }}
            style={{ 
              width: '80px', 
              background: 'rgba(255, 255, 255, 0.1)', 
              border: '1px solid var(--border)',
              borderRadius: '8px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--muted)'
            }}
          >
            1.00
          </motion.div>
          <div style={{ fontSize: '0.9rem', color: 'var(--muted)' }}>{l.bit} (2 states)</div>
        </div>

        {/* Trit */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '1rem' }}>
          <motion.div 
            initial={{ height: 0 }}
            whileInView={{ height: '158px' }} // 1.58x height
            transition={{ duration: 1, delay: 0.2 }}
            style={{ 
              width: '80px', 
              background: 'rgba(0, 229, 153, 0.2)', 
              border: '2px solid var(--accent)',
              borderRadius: '8px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--accent)',
              fontWeight: 'bold',
              position: 'relative',
              boxShadow: '0 0 20px rgba(0, 229, 153, 0.2)'
            }}
          >
            1.58
            <motion.div 
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              transition={{ delay: 1.2 }}
              style={{ 
                position: 'absolute', 
                top: '-30px', 
                whiteSpace: 'nowrap', 
                color: 'var(--accent)', 
                fontSize: '0.8rem',
                fontWeight: 600 
              }}
            >
              {l.efficiency}
            </motion.div>
          </motion.div>
          <div style={{ fontSize: '0.9rem', color: 'var(--accent)', fontWeight: 500 }}>{l.trit} (3 states)</div>
        </div>
      </div>
      
      <div style={{ textAlign: 'center', marginTop: '1.5rem', fontSize: '0.85rem', color: 'var(--muted)' }}>
        log₂(3) ≈ 1.58496 bits
      </div>
    </div>
  )
}
