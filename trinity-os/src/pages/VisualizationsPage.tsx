"use client";
import { motion } from 'framer-motion';
import { useI18n } from '../i18n/context';
import QuantumBackground from '../components/QuantumBackground';
import Footer from '../components/Footer';

const visualizations = [
  { 
    id: 'runtime', 
    icon: '🔮', 
    title: '999 OS Runtime', 
    desc: 'Full quantum computing environment with 29 modules',
    href: '/quantum-runtime.html',
    color: '#ffd700'
  },
  { 
    id: 'quantum59', 
    icon: '🌌', 
    title: 'Quantum Trinity', 
    desc: 'Evolution, Entanglement & Blockchain visualization',
    href: '/quantum-runtime.html',
    color: '#00E599'
  },
  { 
    id: 'quantumlife', 
    icon: '🧬', 
    title: 'Quantum Life', 
    desc: 'Biology + Simulation + Consciousness',
    href: '/quantum-runtime.html',
    color: '#0af'
  },
  { 
    id: 'neuromorphic', 
    icon: '🧠', 
    title: 'Neuromorphic', 
    desc: 'Brain-inspired computing patterns',
    href: '/quantum-runtime.html',
    color: '#f0f'
  },
  { 
    id: 'consciousness', 
    icon: '👁️', 
    title: 'Consciousness', 
    desc: 'Awareness field simulation',
    href: '/quantum-runtime.html',
    color: '#ff6'
  },
  { 
    id: 'trinity', 
    icon: '🔺', 
    title: 'Trinity Core', 
    desc: 'Ternary computing visualization',
    href: '/quantum-runtime.html',
    color: '#f66'
  },
  { 
    id: 'multiverse', 
    icon: '🌀', 
    title: 'Multiverse', 
    desc: 'Parallel reality simulation',
    href: '/quantum-runtime.html',
    color: '#6f6'
  },
  { 
    id: 'encryption', 
    icon: '🔐', 
    title: 'Quantum Encryption', 
    desc: 'Post-quantum cryptography',
    href: '/quantum-runtime.html',
    color: '#66f'
  },
  { 
    id: 'supremacy', 
    icon: '⚡', 
    title: 'Quantum Supremacy', 
    desc: 'Computational advantage demo',
    href: '/quantum-runtime.html',
    color: '#f90'
  },
  { 
    id: 'tsp', 
    icon: '🗺️', 
    title: 'TSP Solver', 
    desc: 'Traveling Salesman quantum optimization',
    href: '/quantum-runtime.html',
    color: '#9f6'
  },
  { 
    id: 'matryoshka', 
    icon: '🪆', 
    title: 'Matryoshka', 
    desc: 'Nested quantum states',
    href: '/quantum-runtime.html',
    color: '#f6f'
  },
  { 
    id: 'zharptitsa', 
    icon: '🔥', 
    title: 'Zhar-Ptitsa', 
    desc: 'Phoenix firebird visualization',
    href: '/quantum-runtime.html',
    color: '#fa0'
  },
];

export default function VisualizationsPage() {
  useI18n(); // For language context

  return (
    <main style={{ background: 'var(--bg)', minHeight: '100vh' }}>
      <QuantumBackground />
      
      {/* Header */}
      <header style={{ 
        position: 'fixed', 
        top: 0, 
        left: 0, 
        right: 0, 
        zIndex: 100,
        background: 'rgba(0,0,0,0.8)',
        backdropFilter: 'blur(20px)',
        borderBottom: '1px solid var(--border)',
        padding: '1rem 2rem',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center'
      }}>
        <a href="/" style={{ color: 'var(--text)', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <span style={{ fontSize: '1.5rem' }}>←</span>
          <span style={{ fontWeight: 600 }}>TRINITY</span>
        </a>
        <div style={{ color: '#ffd700', fontFamily: 'monospace' }}>
          φ² + 1/φ² = 3
        </div>
      </header>

      {/* Hero */}
      <section style={{ 
        paddingTop: '120px', 
        paddingBottom: '4rem',
        textAlign: 'center',
        position: 'relative'
      }}>
        <div className="radial-glow" style={{ opacity: 0.3 }} />
        <motion.h1 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          style={{ 
            fontSize: 'clamp(2rem, 6vw, 3.5rem)', 
            fontWeight: 600,
            marginBottom: '1rem'
          }}
        >
          Quantum <span style={{ color: 'var(--accent)' }}>Visualizations</span>
        </motion.h1>
        <motion.p 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          style={{ 
            color: 'var(--muted)', 
            fontSize: '1.1rem',
            maxWidth: '600px',
            margin: '0 auto'
          }}
        >
          Interactive quantum computing simulations powered by TRINITY 999 OS
        </motion.p>
        
        {/* Launch Runtime Button */}
        <motion.a 
          href="/quantum-runtime.html"
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2 }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: '0.5rem',
            marginTop: '2rem',
            padding: '1rem 2rem',
            background: 'linear-gradient(135deg, var(--accent), #00b377)',
            color: '#000',
            textDecoration: 'none',
            borderRadius: '8px',
            fontWeight: 600,
            fontSize: '1.1rem',
            boxShadow: '0 0 30px rgba(0, 229, 153, 0.3)'
          }}
        >
          🚀 Launch 999 OS Runtime
        </motion.a>
      </section>

      {/* Visualizations Grid */}
      <section style={{ 
        padding: '2rem clamp(1rem, 5vw, 4rem)',
        maxWidth: '1400px',
        margin: '0 auto'
      }}>
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
          gap: '1.5rem'
        }}>
          {visualizations.map((viz, i) => (
            <motion.a
              key={viz.id}
              href={viz.href}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
              viewport={{ once: true }}
              whileHover={{ y: -5, boxShadow: `0 10px 40px ${viz.color}33` }}
              style={{
                display: 'block',
                padding: '1.5rem',
                background: 'rgba(255,255,255,0.02)',
                border: '1px solid var(--border)',
                borderRadius: '12px',
                textDecoration: 'none',
                transition: 'all 0.3s ease'
              }}
            >
              <div style={{ 
                fontSize: '2.5rem', 
                marginBottom: '1rem',
                filter: 'drop-shadow(0 0 10px ' + viz.color + ')'
              }}>
                {viz.icon}
              </div>
              <h3 style={{ 
                color: viz.color, 
                fontSize: '1.2rem', 
                fontWeight: 600,
                marginBottom: '0.5rem'
              }}>
                {viz.title}
              </h3>
              <p style={{ 
                color: 'var(--muted)', 
                fontSize: '0.85rem',
                lineHeight: 1.5
              }}>
                {viz.desc}
              </p>
            </motion.a>
          ))}
        </div>
      </section>

      {/* Formula Section */}
      <section style={{ 
        padding: '4rem 2rem',
        textAlign: 'center'
      }}>
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          style={{
            display: 'inline-block',
            padding: '2rem 3rem',
            background: 'rgba(255,215,0,0.05)',
            border: '1px solid rgba(255,215,0,0.2)',
            borderRadius: '12px'
          }}
        >
          <div style={{ 
            color: '#ffd700', 
            fontSize: 'clamp(1.5rem, 4vw, 2.5rem)', 
            fontFamily: 'monospace',
            marginBottom: '0.5rem'
          }}>
            φ² + 1/φ² = 3
          </div>
          <div style={{ color: '#f66', fontSize: '1rem' }}>
            PHOENIX = 999
          </div>
          <div style={{ color: 'var(--muted)', fontSize: '0.8rem', marginTop: '0.5rem' }}>
            KOSCHEI IS IMMORTAL
          </div>
        </motion.div>
      </section>

      <Footer />
    </main>
  );
}
