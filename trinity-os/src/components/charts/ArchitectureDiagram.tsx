"use client";
import { motion } from "framer-motion";

export default function ArchitectureDiagram({ labels }: { labels?: any }) {
  const l = labels || {
    title: "Native Ternary Architecture",
    core: "SU(3) CORE",
    input: "Input Stream",
    inference: "Inference",
    daemon: "PAS Daemon"
  }

  return (
    <div className="premium-card fade" style={{ 
      width: '100%', 
      maxWidth: '850px', 
      margin: '3rem auto', 
      padding: 'clamp(1rem, 5vw, 2.5rem)', 
      position: 'relative', 
      overflow: 'hidden' 
    }}>
      <h3 style={{ textAlign: 'center', marginBottom: 'clamp(1.5rem, 5vw, 2.5rem)', fontSize: 'clamp(1.2rem, 4vw, 1.8rem)' }}>{l.title}</h3>
      
      <svg viewBox="0 0 600 350" style={{ width: '100%', height: 'auto', display: 'block' }}>
        {/* Core Unit */}
        <motion.g
           initial={{ opacity: 0, scale: 0.9 }}
           whileInView={{ opacity: 1, scale: 1 }}
           transition={{ duration: 1 }}
        >
          <rect x="200" y="140" width="200" height="180" rx="12" fill="rgba(0, 229, 153, 0.08)" stroke="var(--accent)" strokeWidth="2.5" />
          <text x="300" y="240" textAnchor="middle" fill="var(--accent)" fontSize="20" fontWeight="700" letterSpacing="0.05em">{l.core}</text>
        </motion.g>

        {/* Input Flow */}
        <motion.path 
           d="M 20,230 L 200,230" 
           stroke="var(--muted)" 
           strokeWidth="2" 
           strokeDasharray="6,6"
           initial={{ pathLength: 0 }}
           whileInView={{ pathLength: 1 }}
           transition={{ duration: 1.5 }}
        />
        <text x="110" y="215" textAnchor="middle" fill="var(--muted)" fontSize="13" fontWeight="500">{l.input}</text>

        {/* Output Flow */}
        <motion.path 
           d="M 400,230 L 580,230" 
           stroke="var(--muted)" 
           strokeWidth="2" 
           strokeDasharray="6,6" 
           initial={{ pathLength: 0 }}
           whileInView={{ pathLength: 1 }}
           transition={{ duration: 1.5, delay: 0.5 }}
        />
        <text x="490" y="215" textAnchor="middle" fill="var(--muted)" fontSize="13" fontWeight="500">{l.inference}</text>

        {/* PAS Loop */}
        <motion.circle 
           cx="300" 
           cy="75" 
           r="45" 
           fill="rgba(255,255,255,0.02)" 
           stroke="var(--text)" 
           strokeWidth="2"
           initial={{ opacity: 0, scale: 0.8 }}
           whileInView={{ opacity: 1, scale: 1 }}
           transition={{ delay: 0.8 }}
        />
        <text x="300" y="80" textAnchor="middle" fill="var(--text)" fontSize="11" fontWeight="600" style={{ textTransform: 'uppercase' }}>{l.daemon}</text>

        {/* Connection to Core */}
        <motion.path 
           d="M 300,120 L 300,140" 
           stroke="var(--accent)" 
           strokeWidth="2.5" 
           initial={{ pathLength: 0 }}
           whileInView={{ pathLength: 1 }}
           transition={{ delay: 1 }}
        />
        
        {/* Particles */}
         <motion.circle 
           cy="230" r="5" fill="var(--accent)"
           initial={{ cx: 50 }}
           animate={{ cx: 550 }}
           transition={{ repeat: Infinity, duration: 2.5, ease: "linear" }}
           style={{ filter: 'drop-shadow(0 0 5px var(--accent))' }}
         />
      </svg>
    </div>
  )
}
