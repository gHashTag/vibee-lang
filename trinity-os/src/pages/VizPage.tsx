"use client";
import { motion } from 'framer-motion';
import { useParams, Link } from 'react-router-dom';
import QuantumCanvas from '../components/QuantumCanvas';
import type { VizMode } from '../components/QuantumCanvas';

const vizList = [
  { id: 'quantum-field', icon: '⚛️', title: 'Quantum Field', color: '#00E599' },
  { id: 'neural-network', icon: '🧠', title: 'Neural Network', color: '#0af' },
  { id: 'wave-interference', icon: '🌊', title: 'Wave', color: '#6f6' },
  { id: 'entanglement', icon: '🔗', title: 'Entangle', color: '#f6f' },
  { id: 'vortex', icon: '🌀', title: 'Vortex', color: '#fa0' },
  { id: 'photon-beam', icon: '💫', title: 'Photon', color: '#ff6' },
  { id: 'consciousness', icon: '👁️', title: 'Mind', color: '#a6f' },
  { id: 'trinity', icon: '🔺', title: 'Trinity', color: '#0e9' },
  { id: 'multiverse', icon: '🌌', title: 'Multi', color: '#48f' },
  { id: 'zhar-ptitsa', icon: '🔥', title: 'Phoenix', color: '#f80' },
  { id: 'matryoshka', icon: '🪆', title: 'Nested', color: '#e4a' },
  { id: 'supremacy', icon: '⚡', title: 'Supreme', color: '#f44' },
];

const vizData: Record<string, { title: string; subtitle: string; color: string; icon: string }> = {
  'quantum-field': { title: 'Quantum Field', subtitle: 'Superposition & Wave Functions', color: '#00E599', icon: '⚛️' },
  'neural-network': { title: 'Neural Network', subtitle: 'Neuromorphic Computing', color: '#0af', icon: '🧠' },
  'wave-interference': { title: 'Wave Interference', subtitle: 'Double-Slit Experiment', color: '#6f6', icon: '🌊' },
  'entanglement': { title: 'Quantum Entanglement', subtitle: 'Spooky Action at Distance', color: '#f6f', icon: '🔗' },
  'vortex': { title: 'Vortex Field', subtitle: 'Spiral Dynamics', color: '#fa0', icon: '🌀' },
  'photon-beam': { title: 'Photon Beam', subtitle: 'Light Propagation', color: '#ff6', icon: '💫' },
  'consciousness': { title: 'Consciousness', subtitle: 'Awareness Field Simulation', color: '#a6f', icon: '👁️' },
  'trinity': { title: 'Trinity Core', subtitle: 'Ternary Computing Visualization', color: '#0e9', icon: '🔺' },
  'multiverse': { title: 'Multiverse', subtitle: 'Parallel Reality Simulation', color: '#48f', icon: '🌌' },
  'encryption': { title: 'Quantum Encryption', subtitle: 'Post-Quantum Cryptography', color: '#0cf', icon: '🔐' },
  'supremacy': { title: 'Quantum Supremacy', subtitle: 'Computational Advantage', color: '#f44', icon: '⚡' },
  'tsp': { title: 'TSP Solver', subtitle: 'Traveling Salesman Optimization', color: '#4a4', icon: '🗺️' },
  'neuromorphic': { title: 'Neuromorphic', subtitle: 'Brain-Inspired Patterns', color: '#c4f', icon: '🧬' },
  'spintronic': { title: 'Spintronic', subtitle: 'Electron Spin Dynamics', color: '#f4a', icon: '🔄' },
  'transcendence': { title: 'Transcendence', subtitle: 'Beyond Physical Limits', color: '#ff0', icon: '✨' },
  'living': { title: 'Living Systems', subtitle: 'Organic Computation', color: '#4f4', icon: '🌱' },
  'quantum-life': { title: 'Quantum Life', subtitle: 'Biology + Simulation', color: '#0fa', icon: '🧬' },
  'quantum-agents': { title: 'Quantum Agents', subtitle: 'Autonomous Particles', color: '#4af', icon: '🤖' },
  'matryoshka': { title: 'Matryoshka', subtitle: 'Nested Quantum States', color: '#e4a', icon: '🪆' },
  'zhar-ptitsa': { title: 'Zhar-Ptitsa', subtitle: 'Phoenix Firebird', color: '#f80', icon: '🔥' },
  'bogatyri': { title: 'Bogatyri 33', subtitle: 'Three Heroes Formation', color: '#48f', icon: '⚔️' },
  'qec': { title: 'QEC', subtitle: 'Quantum Error Correction', color: '#0af', icon: '🛡️' },
  'obfuscation': { title: 'Obfuscation', subtitle: 'Code Protection', color: '#a4f', icon: '🎭' },
  'secure': { title: 'Secure Channel', subtitle: 'Encrypted Communication', color: '#0fa', icon: '🔒' },
  'beings': { title: 'Digital Beings', subtitle: 'Emergent Consciousness', color: '#f4a', icon: '👾' },
  'pas': { title: 'PAS Analysis', subtitle: 'Pattern Recognition', color: '#4a4', icon: '📊' },
  'quantum-biology': { title: 'Quantum Biology', subtitle: 'Life at Quantum Scale', color: '#0fa', icon: '🦠' },
  'llm-architecture': { title: 'LLM Architecture', subtitle: 'Neural Language Model', color: '#48f', icon: '🏗️' },
  'cinema4d': { title: 'Cinema 4D', subtitle: '3D Grid Visualization', color: '#f4a', icon: '🎬' },
};

export default function VizPage() {
  const { vizId } = useParams<{ vizId: string }>();
  const viz = vizData[vizId || 'quantum-field'] || vizData['quantum-field'];
  const mode = (vizId || 'quantum-field') as VizMode;

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000' }}>
      {/* Fullscreen Canvas */}
      <QuantumCanvas mode={mode} particleCount={2000} interactive={true} />
      
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
            fontWeight: 500,
            transition: 'color 0.2s'
          }}
        >
          TRINITY
        </Link>
        
        <div style={{ width: '1px', height: '20px', background: 'rgba(255,255,255,0.1)' }} />
        
        {vizList.map(v => (
          <Link 
            key={v.id}
            to={`/viz/${v.id}`}
            style={{ 
              padding: '0.6rem 0.8rem',
              background: vizId === v.id ? 'rgba(255,255,255,0.15)' : 'transparent',
              borderRadius: '100px',
              color: vizId === v.id ? v.color : 'rgba(255,255,255,0.5)',
              textDecoration: 'none',
              fontSize: '1.1rem',
              transition: 'all 0.3s ease',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            {v.icon}
          </Link>
        ))}
      </motion.header>

      {/* Floating Title - Bottom Left */}
      <motion.div
        initial={{ opacity: 0, x: -30 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.6, delay: 0.2 }}
        style={{
          position: 'fixed',
          bottom: 'clamp(2rem, 5vw, 4rem)',
          left: 'clamp(1.5rem, 4vw, 3rem)',
          zIndex: 100
        }}
      >
        <div style={{ 
          fontSize: '3rem', 
          marginBottom: '0.5rem',
          filter: `drop-shadow(0 0 20px ${viz.color})`
        }}>
          {viz.icon}
        </div>
        <h1 style={{ 
          fontSize: 'clamp(1.5rem, 4vw, 2.5rem)', 
          fontWeight: 600,
          color: '#fff',
          marginBottom: '0.25rem',
          letterSpacing: '-0.02em'
        }}>
          {viz.title}
        </h1>
        <p style={{ 
          color: 'rgba(255,255,255,0.5)', 
          fontSize: 'clamp(0.85rem, 2vw, 1rem)',
          fontWeight: 400
        }}>
          {viz.subtitle}
        </p>
      </motion.div>

      {/* Floating Formula - Bottom Right */}
      <motion.div
        initial={{ opacity: 0, x: 30 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.6, delay: 0.3 }}
        style={{
          position: 'fixed',
          bottom: 'clamp(2rem, 5vw, 4rem)',
          right: 'clamp(1.5rem, 4vw, 3rem)',
          zIndex: 100,
          textAlign: 'right'
        }}
      >
        <div style={{ 
          color: '#ffd700', 
          fontSize: 'clamp(1rem, 2.5vw, 1.5rem)', 
          fontFamily: 'monospace',
          fontWeight: 500,
          textShadow: '0 0 30px rgba(255,215,0,0.3)'
        }}>
          φ² + 1/φ² = 3
        </div>
        <div style={{ 
          color: 'rgba(255,255,255,0.3)', 
          fontSize: '0.75rem',
          marginTop: '0.25rem'
        }}>
          Click & drag to interact
        </div>
      </motion.div>

      {/* Subtle Gradient Overlays */}
      <div style={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        height: '200px',
        background: 'linear-gradient(to top, rgba(0,0,0,0.6), transparent)',
        pointerEvents: 'none',
        zIndex: 50
      }} />
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        height: '120px',
        background: 'linear-gradient(to bottom, rgba(0,0,0,0.4), transparent)',
        pointerEvents: 'none',
        zIndex: 50
      }} />
    </div>
  );
}
