"use client";
import { motion } from 'framer-motion';
import { useParams, Link } from 'react-router-dom';
import QuantumCanvas from '../components/QuantumCanvas';
import type { VizMode } from '../components/QuantumCanvas';
import Footer from '../components/Footer';

const vizList = [
  { id: 'quantum-field', icon: '⚛️', color: '#00E599' },
  { id: 'neural-network', icon: '🧠', color: '#0af' },
  { id: 'wave-interference', icon: '🌊', color: '#6f6' },
  { id: 'entanglement', icon: '🔗', color: '#f6f' },
  { id: 'vortex', icon: '🌀', color: '#fa0' },
  { id: 'photon-beam', icon: '💫', color: '#ff6' },
];

const vizData: Record<string, { title: string; subtitle: string; description: string; color: string; icon: string }> = {
  'quantum-field': {
    title: 'Quantum Field',
    subtitle: 'Superposition & Wave Functions',
    description: 'Visualization of quantum superposition states. Particles exist in multiple states simultaneously, influenced by wave functions based on the golden ratio φ.',
    color: '#00E599',
    icon: '⚛️'
  },
  'neural-network': {
    title: 'Neural Network',
    subtitle: 'Neuromorphic Computing',
    description: 'Brain-inspired computing patterns. Particles form layered connections mimicking neural pathways and synaptic transmission.',
    color: '#0af',
    icon: '🧠'
  },
  'wave-interference': {
    title: 'Wave Interference',
    subtitle: 'Double-Slit Experiment',
    description: 'Classic quantum mechanics demonstration. Two wave sources create interference patterns, showing the wave nature of quantum particles.',
    color: '#6f6',
    icon: '🌊'
  },
  'entanglement': {
    title: 'Quantum Entanglement',
    subtitle: 'Spooky Action at Distance',
    description: 'Entangled particle pairs with correlated spins. When one particle changes state, its entangled partner instantly responds regardless of distance.',
    color: '#f6f',
    icon: '🔗'
  },
  'vortex': {
    title: 'Vortex Field',
    subtitle: 'Spiral Dynamics',
    description: 'Particles caught in a quantum vortex, spiraling around a central attractor. Demonstrates angular momentum in quantum systems.',
    color: '#fa0',
    icon: '🌀'
  },
  'photon-beam': {
    title: 'Photon Beam',
    subtitle: 'Light Propagation',
    description: 'Photons emanating from a central source, demonstrating wave-particle duality and the propagation of light through space.',
    color: '#ff6',
    icon: '💫'
  }
};

export default function VizPage() {
  const { vizId } = useParams<{ vizId: string }>();
  const viz = vizData[vizId || 'quantum-field'] || vizData['quantum-field'];
  const mode = (vizId || 'quantum-field') as VizMode;

  return (
    <main style={{ background: '#000', minHeight: '100vh' }}>
      {/* Header */}
      <header style={{ 
        position: 'fixed', 
        top: 0, 
        left: 0, 
        right: 0, 
        zIndex: 100,
        background: 'rgba(0,0,0,0.9)',
        backdropFilter: 'blur(20px)',
        borderBottom: '1px solid rgba(255,255,255,0.1)',
        padding: '0.75rem clamp(1rem, 3vw, 2rem)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        gap: '1rem'
      }}>
        <Link to="/" style={{ color: 'var(--text)', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '0.5rem', flexShrink: 0 }}>
          <span style={{ fontWeight: 700, fontSize: '1.1rem' }}>TRINITY</span>
        </Link>
        
        {/* Quick Nav */}
        <nav style={{ display: 'flex', gap: '0.4rem', flexWrap: 'wrap', justifyContent: 'center' }}>
          {vizList.map(v => (
            <Link 
              key={v.id}
              to={`/viz/${v.id}`}
              style={{ 
                padding: '0.4rem 0.6rem',
                background: vizId === v.id ? `${v.color}22` : 'rgba(255,255,255,0.05)',
                border: `1px solid ${vizId === v.id ? v.color : 'var(--border)'}`,
                borderRadius: '6px',
                color: v.color,
                textDecoration: 'none',
                fontSize: '0.9rem',
                transition: 'all 0.2s'
              }}
            >
              {v.icon}
            </Link>
          ))}
        </nav>

        <div style={{ color: '#ffd700', fontFamily: 'monospace', fontSize: '0.75rem', flexShrink: 0 }}>
          φ² + 1/φ² = 3
        </div>
      </header>

      {/* Canvas Section */}
      <section style={{ 
        position: 'relative',
        height: '70vh',
        minHeight: '500px',
        paddingTop: '60px'
      }}>
        <QuantumCanvas mode={mode} particleCount={2000} interactive={true} />
        
        {/* Overlay Info */}
        <div style={{
          position: 'absolute',
          bottom: '2rem',
          left: '2rem',
          right: '2rem',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'flex-end',
          pointerEvents: 'none'
        }}>
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
          >
            <div style={{ fontSize: '3rem', marginBottom: '0.5rem' }}>{viz.icon}</div>
            <h1 style={{ 
              fontSize: 'clamp(1.5rem, 4vw, 2.5rem)', 
              fontWeight: 600,
              color: viz.color,
              marginBottom: '0.25rem'
            }}>
              {viz.title}
            </h1>
            <p style={{ color: 'var(--muted)', fontSize: '1rem' }}>{viz.subtitle}</p>
          </motion.div>
          
          <div style={{ 
            background: 'rgba(0,0,0,0.6)', 
            padding: '0.75rem 1rem', 
            borderRadius: '8px',
            fontSize: '0.8rem',
            color: 'var(--muted)'
          }}>
            Click & drag to interact
          </div>
        </div>
      </section>

      {/* Description Section */}
      <section style={{ 
        padding: 'clamp(2rem, 5vw, 4rem)',
        maxWidth: '900px',
        margin: '0 auto'
      }}>
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="premium-card"
          style={{ padding: '2rem' }}
        >
          <h2 style={{ 
            fontSize: '1.5rem', 
            marginBottom: '1rem',
            color: viz.color
          }}>
            About This Visualization
          </h2>
          <p style={{ 
            color: 'var(--muted)', 
            lineHeight: 1.8,
            fontSize: '1rem'
          }}>
            {viz.description}
          </p>
          
          <div style={{ 
            marginTop: '2rem',
            padding: '1rem',
            background: 'rgba(255,215,0,0.05)',
            borderRadius: '8px',
            border: '1px solid rgba(255,215,0,0.1)'
          }}>
            <div style={{ color: '#ffd700', fontFamily: 'monospace', fontSize: '1.2rem', textAlign: 'center' }}>
              φ² + 1/φ² = 3
            </div>
            <div style={{ color: 'var(--muted)', fontSize: '0.8rem', textAlign: 'center', marginTop: '0.5rem' }}>
              The Golden Identity powering TRINITY computing
            </div>
          </div>
        </motion.div>

        {/* Other Visualizations */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          style={{ marginTop: '3rem' }}
        >
          <h3 style={{ fontSize: '1.2rem', marginBottom: '1.5rem', color: 'var(--text)' }}>
            Explore More
          </h3>
          <div style={{ 
            display: 'grid', 
            gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))',
            gap: '1rem'
          }}>
            {Object.entries(vizData).filter(([id]) => id !== vizId).map(([id, v]) => (
              <Link
                key={id}
                to={`/viz/${id}`}
                style={{
                  display: 'block',
                  padding: '1rem',
                  background: 'rgba(255,255,255,0.02)',
                  border: '1px solid var(--border)',
                  borderRadius: '8px',
                  textDecoration: 'none',
                  textAlign: 'center',
                  transition: 'all 0.3s ease'
                }}
              >
                <div style={{ fontSize: '1.5rem', marginBottom: '0.5rem' }}>{v.icon}</div>
                <div style={{ color: v.color, fontSize: '0.85rem', fontWeight: 500 }}>{v.title}</div>
              </Link>
            ))}
          </div>
        </motion.div>
      </section>

      <Footer />
    </main>
  );
}
