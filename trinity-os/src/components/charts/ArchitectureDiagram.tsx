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
    <div className="premium-card fade" style={{ width: '100%', maxWidth: '800px', margin: '3rem auto', padding: '3rem', position: 'relative', overflow: 'hidden' }}>
      <h3 style={{ textAlign: 'center', marginBottom: '3rem' }}>{l.title}</h3>
      
      <svg viewBox="0 0 800 400" style={{ width: '100%', height: 'auto' }}>
        {/* Core Unit */}
        <motion.g
           initial={{ opacity: 0, scale: 0.8 }}
           whileInView={{ opacity: 1, scale: 1 }}
           transition={{ duration: 1 }}
        >
          <rect x="300" y="150" width="200" height="200" rx="10" fill="rgba(0, 229, 153, 0.1)" stroke="var(--accent)" strokeWidth="2" />
          <text x="400" y="255" textAnchor="middle" fill="var(--accent)" fontSize="24" fontWeight="bold">{l.core}</text>
        </motion.g>

        {/* Input Flow */}
        <motion.path 
           d="M 100,250 L 300,250" 
           stroke="var(--muted)" 
           strokeWidth="2" 
           strokeDasharray="5,5"
           initial={{ pathLength: 0 }}
           whileInView={{ pathLength: 1 }}
           transition={{ duration: 1.5 }}
        />
        <text x="200" y="240" textAnchor="middle" fill="var(--muted)" fontSize="14">{l.input}</text>

        {/* Output Flow */}
        <motion.path 
           d="M 500,250 L 700,250" 
           stroke="var(--muted)" 
           strokeWidth="2" 
           strokeDasharray="5,5" 
           initial={{ pathLength: 0 }}
           whileInView={{ pathLength: 1 }}
           transition={{ duration: 1.5, delay: 0.5 }}
        />
        <text x="600" y="240" textAnchor="middle" fill="var(--muted)" fontSize="14">{l.inference}</text>

        {/* PAS Loop */}
        <motion.circle 
           cx="400" 
           cy="100" 
           r="40" 
           fill="none" 
           stroke="var(--text)" 
           strokeWidth="2"
           initial={{ opacity: 0, scale: 0.8 }}
           whileInView={{ opacity: 1, scale: 1 }}
           transition={{ delay: 0.8 }}
        />
        <text x="400" y="105" textAnchor="middle" fill="var(--text)" fontSize="12">{l.daemon}</text>

        {/* Connection to Core */}
        <motion.path 
           d="M 400,140 L 400,150" 
           stroke="var(--accent)" 
           strokeWidth="2" 
           initial={{ pathLength: 0 }}
           whileInView={{ pathLength: 1 }}
           transition={{ delay: 1 }}
        />
        
        {/* Particles */}
         <motion.circle 
           cy="250" r="4" fill="var(--accent)"
           initial={{ cx: 150 }}
           animate={{ cx: 650 }}
           transition={{ repeat: Infinity, duration: 3, ease: "linear" }}
         />
      </svg>
    </div>
  )
}
