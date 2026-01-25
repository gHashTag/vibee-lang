"use client";
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import QuantumCanvas from '../components/QuantumCanvas';

const visualizations = [
  { id: 'quantum-field', icon: '⚛️', title: 'Quantum Field', desc: 'Superposition & wave functions', color: '#00E599' },
  { id: 'neural-network', icon: '🧠', title: 'Neural Network', desc: 'Brain-inspired patterns', color: '#0af' },
  { id: 'wave-interference', icon: '🌊', title: 'Wave Interference', desc: 'Double-slit simulation', color: '#6f6' },
  { id: 'entanglement', icon: '🔗', title: 'Entanglement', desc: 'Correlated quantum pairs', color: '#f6f' },
  { id: 'vortex', icon: '🌀', title: 'Vortex Field', desc: 'Spiral dynamics', color: '#fa0' },
  { id: 'photon-beam', icon: '💫', title: 'Photon Beam', desc: 'Light propagation', color: '#ff6' },
  { id: 'consciousness', icon: '👁️', title: 'Consciousness', desc: 'Awareness field simulation', color: '#a6f' },
  { id: 'trinity', icon: '🔺', title: 'Trinity Core', desc: 'Ternary computing', color: '#0e9' },
  { id: 'multiverse', icon: '🌌', title: 'Multiverse', desc: 'Parallel realities', color: '#48f' },
  { id: 'zhar-ptitsa', icon: '🔥', title: 'Zhar-Ptitsa', desc: 'Phoenix firebird', color: '#f80' },
  { id: 'matryoshka', icon: '🪆', title: 'Matryoshka', desc: 'Nested quantum states', color: '#e4a' },
  { id: 'supremacy', icon: '⚡', title: 'Supremacy', desc: 'Quantum advantage', color: '#f44' },
  { id: 'encryption', icon: '🔐', title: 'Encryption', desc: 'Post-quantum crypto', color: '#0cf' },
  { id: 'tsp', icon: '🗺️', title: 'TSP Solver', desc: 'Route optimization', color: '#4a4' },
  { id: 'neuromorphic', icon: '🧬', title: 'Neuromorphic', desc: 'Brain computing', color: '#c4f' },
  { id: 'quantum-life', icon: '🦠', title: 'Quantum Life', desc: 'Biology simulation', color: '#0fa' },
  { id: 'bogatyri', icon: '⚔️', title: 'Bogatyri 33', desc: 'Three heroes', color: '#48f' },
  { id: 'llm-architecture', icon: '🏗️', title: 'LLM Architecture', desc: 'Neural language', color: '#48f' },
];

export default function VisualizationsPage() {
  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000' }}>
      {/* Fullscreen Canvas Background */}
      <div style={{ position: 'absolute', inset: 0, opacity: 0.6 }}>
        <QuantumCanvas mode="quantum-field" particleCount={800} interactive={false} />
      </div>

      {/* Floating Header */}
      <motion.header 
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        style={{ 
          position: 'fixed', 
          top: 'clamp(1rem, 3vw, 2rem)', 
          left: '50%',
          transform: 'translateX(-50%)',
          zIndex: 100,
          display: 'flex',
          alignItems: 'center',
          gap: '0.5rem',
          padding: '0.5rem',
          background: 'rgba(0,0,0,0.4)',
          backdropFilter: 'blur(20px)',
          WebkitBackdropFilter: 'blur(20px)',
          borderRadius: '100px',
          border: '1px solid rgba(255,255,255,0.1)',
        }}
      >
        <Link 
          to="/" 
          style={{ 
            padding: '0.6rem 1rem',
            color: 'rgba(255,255,255,0.7)',
            textDecoration: 'none',
            fontSize: '0.85rem',
            fontWeight: 500
          }}
        >
          TRINITY
        </Link>
        
        <div style={{ width: '1px', height: '20px', background: 'rgba(255,255,255,0.1)' }} />
        
        {visualizations.map(v => (
          <Link 
            key={v.id}
            to={`/viz/${v.id}`}
            style={{ 
              padding: '0.6rem 0.8rem',
              borderRadius: '100px',
              color: 'rgba(255,255,255,0.5)',
              textDecoration: 'none',
              fontSize: '1.1rem',
              transition: 'all 0.3s ease'
            }}
          >
            {v.icon}
          </Link>
        ))}
      </motion.header>

      {/* Content */}
      <div style={{
        position: 'relative',
        zIndex: 60,
        minHeight: '100vh',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        alignItems: 'center',
        padding: 'clamp(1rem, 5vw, 3rem)'
      }}>
        {/* Title */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          style={{ textAlign: 'center', marginBottom: '3rem' }}
        >
          <h1 style={{ 
            fontSize: 'clamp(2rem, 6vw, 4rem)', 
            fontWeight: 600,
            color: '#fff',
            letterSpacing: '-0.03em',
            marginBottom: '0.5rem'
          }}>
            Quantum <span style={{ color: 'var(--accent)' }}>Visualizations</span>
          </h1>
          <p style={{ 
            color: 'rgba(255,255,255,0.5)', 
            fontSize: 'clamp(0.9rem, 2vw, 1.1rem)'
          }}>
            Interactive simulations powered by TRINITY
          </p>
        </motion.div>

        {/* Cards Grid */}
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          gap: '1.5rem',
          maxWidth: '1000px',
          width: '100%'
        }}>
          {visualizations.map((viz, i) => (
            <Link key={viz.id} to={`/viz/${viz.id}`} style={{ textDecoration: 'none' }}>
              <motion.div
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.1 + i * 0.08, duration: 0.5 }}
                whileHover={{ 
                  y: -8, 
                  scale: 1.02,
                  boxShadow: `0 20px 60px ${viz.color}33`
                }}
                style={{
                  padding: '2rem',
                  background: 'rgba(255,255,255,0.03)',
                  backdropFilter: 'blur(10px)',
                  WebkitBackdropFilter: 'blur(10px)',
                  border: '1px solid rgba(255,255,255,0.08)',
                  borderRadius: '20px',
                  cursor: 'pointer',
                  transition: 'all 0.4s cubic-bezier(0.16, 1, 0.3, 1)'
                }}
              >
                <div style={{ 
                  fontSize: '2.5rem', 
                  marginBottom: '1rem',
                  filter: `drop-shadow(0 0 15px ${viz.color})`
                }}>
                  {viz.icon}
                </div>
                <h3 style={{ 
                  color: '#fff', 
                  fontSize: '1.25rem', 
                  fontWeight: 600,
                  marginBottom: '0.5rem',
                  letterSpacing: '-0.01em'
                }}>
                  {viz.title}
                </h3>
                <p style={{ 
                  color: 'rgba(255,255,255,0.4)', 
                  fontSize: '0.9rem',
                  lineHeight: 1.5
                }}>
                  {viz.desc}
                </p>
              </motion.div>
            </Link>
          ))}
        </div>

        {/* Formula */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8 }}
          style={{ 
            marginTop: '4rem',
            textAlign: 'center'
          }}
        >
          <div style={{ 
            color: '#ffd700', 
            fontSize: 'clamp(1.2rem, 3vw, 1.8rem)', 
            fontFamily: 'monospace',
            textShadow: '0 0 40px rgba(255,215,0,0.3)'
          }}>
            φ² + 1/φ² = 3
          </div>
          <div style={{ 
            color: 'rgba(255,255,255,0.3)', 
            fontSize: '0.8rem',
            marginTop: '0.5rem'
          }}>
            PHOENIX = 999
          </div>
        </motion.div>
      </div>

      {/* Gradient Overlays */}
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        height: '150px',
        background: 'linear-gradient(to bottom, rgba(0,0,0,0.8), transparent)',
        pointerEvents: 'none',
        zIndex: 55
      }} />
      <div style={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        height: '150px',
        background: 'linear-gradient(to top, rgba(0,0,0,0.8), transparent)',
        pointerEvents: 'none',
        zIndex: 55
      }} />
    </div>
  );
}
