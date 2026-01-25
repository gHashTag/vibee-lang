"use client";
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import QuantumBackground from '../components/QuantumBackground';
import QuantumCanvas from '../components/QuantumCanvas';
import Footer from '../components/Footer';

const visualizations = [
  { 
    id: 'quantum-field', 
    icon: '⚛️', 
    title: 'Quantum Field', 
    desc: 'Superposition & wave functions visualization',
    href: '/viz/quantum-field',
    color: '#00E599'
  },
  { 
    id: 'neural-network', 
    icon: '🧠', 
    title: 'Neural Network', 
    desc: 'Brain-inspired computing patterns',
    href: '/viz/neural-network',
    color: '#0af'
  },
  { 
    id: 'wave-interference', 
    icon: '🌊', 
    title: 'Wave Interference', 
    desc: 'Double-slit experiment simulation',
    href: '/viz/wave-interference',
    color: '#6f6'
  },
  { 
    id: 'entanglement', 
    icon: '🔗', 
    title: 'Entanglement', 
    desc: 'Correlated quantum pairs with spin',
    href: '/viz/entanglement',
    color: '#f6f'
  },
  { 
    id: 'vortex', 
    icon: '🌀', 
    title: 'Vortex Field', 
    desc: 'Spiral dynamics visualization',
    href: '/viz/vortex',
    color: '#fa0'
  },
  { 
    id: 'photon-beam', 
    icon: '💫', 
    title: 'Photon Beam', 
    desc: 'Light propagation from source',
    href: '/viz/photon-beam',
    color: '#ff6'
  },
];

export default function VisualizationsPage() {

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
        background: 'rgba(0,0,0,0.9)',
        backdropFilter: 'blur(20px)',
        borderBottom: '1px solid var(--border)',
        padding: '0.75rem clamp(1rem, 3vw, 2rem)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center'
      }}>
        <Link to="/" style={{ color: 'var(--text)', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <span style={{ fontWeight: 700, fontSize: '1.1rem' }}>TRINITY</span>
        </Link>
        
        {/* Quick Nav */}
        <nav style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', justifyContent: 'center' }}>
          {visualizations.slice(0, 6).map(v => (
            <Link 
              key={v.id}
              to={v.href}
              style={{ 
                padding: '0.4rem 0.6rem',
                background: 'rgba(255,255,255,0.05)',
                border: '1px solid var(--border)',
                borderRadius: '6px',
                color: v.color,
                textDecoration: 'none',
                fontSize: '0.75rem',
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
                transition: 'all 0.2s'
              }}
            >
              {v.icon}
            </Link>
          ))}
        </nav>

        <div style={{ color: '#ffd700', fontFamily: 'monospace', fontSize: '0.8rem' }}>
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
        
      </section>

      {/* Hero Canvas */}
      <section style={{ 
        height: '40vh', 
        minHeight: '300px',
        position: 'relative',
        margin: '0 2rem 2rem'
      }}>
        <div style={{
          position: 'absolute',
          inset: 0,
          borderRadius: '16px',
          overflow: 'hidden',
          border: '1px solid var(--border)'
        }}>
          <QuantumCanvas mode="quantum-field" particleCount={1000} interactive={true} />
        </div>
        <div style={{
          position: 'absolute',
          bottom: '1rem',
          left: '1rem',
          background: 'rgba(0,0,0,0.6)',
          padding: '0.5rem 1rem',
          borderRadius: '6px',
          fontSize: '0.8rem',
          color: 'var(--muted)'
        }}>
          Interactive preview • Click & drag
        </div>
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
            <Link
              key={viz.id}
              to={viz.href}
              style={{ textDecoration: 'none' }}
            >
              <motion.div
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.05 }}
                viewport={{ once: true }}
                whileHover={{ y: -5, boxShadow: `0 10px 40px ${viz.color}33` }}
                style={{
                  padding: '1.5rem',
                  background: 'rgba(255,255,255,0.02)',
                  border: '1px solid var(--border)',
                  borderRadius: '12px',
                  transition: 'all 0.3s ease',
                  height: '100%'
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
              </motion.div>
            </Link>
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
