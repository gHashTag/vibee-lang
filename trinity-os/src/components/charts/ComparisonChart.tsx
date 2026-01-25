"use client";
import { motion } from "framer-motion";

interface ComparisonProps {
  data: { model: string; value: number; color: string }[];
  title?: string;
  note?: string;
}

export default function ComparisonChart({ data, title, note }: ComparisonProps) {
  return (
    <div className="premium-card fade" style={{ width: '100%', maxWidth: '800px', margin: '0 auto', padding: 'clamp(1rem, 5vw, 2.5rem)' }}>
      <h3 style={{ fontSize: 'clamp(1rem, 4vw, 1.2rem)', marginBottom: '2rem', textAlign: 'center' }}>
        {title || "Relative Performance (Normalized)"}
      </h3>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1.2rem' }}>
        {data.map((row, i) => (
          <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text)', textAlign: 'left', fontWeight: 500, opacity: 0.8 }}>{row.model}</div>
            <div style={{ flex: 1, height: '28px', background: 'rgba(255,255,255,0.05)', borderRadius: '4px', position: 'relative', overflow: 'hidden' }}>
              <motion.div 
                initial={{ width: 0 }}
                whileInView={{ width: `${(row.value / 80) * 100}%` }}
                viewport={{ once: true }}
                transition={{ duration: 1.5, ease: "easeOut", delay: i * 0.2 }}
                style={{ 
                  height: '100%', 
                  background: row.color, 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'flex-end', 
                  paddingRight: '0.8rem',
                  borderRadius: '4px'
                }}
              >
                <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#000', whiteSpace: 'nowrap' }}>{row.value}</span>
              </motion.div>
            </div>
          </div>
        ))}
      </div>
      <div style={{ marginTop: '1.5rem', textAlign: 'center', fontSize: '0.75rem', color: 'var(--muted)', opacity: 0.7 }}>
        {note || "* Higher is better. Based on BitNet b1.58 Inference Benchmarks."}
      </div>
    </div>
  );
}
