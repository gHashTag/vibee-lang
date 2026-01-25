"use client";
import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link } from 'react-router-dom';
import QuantumCanvas from '../components/QuantumCanvas';
import type { VizMode } from '../components/QuantumCanvas';

const categories = [
  {
    name: 'Quantum',
    modes: [
      { id: 'quantum-field', icon: '⚛️', title: 'Quantum Field', color: '#00E599' },
      { id: 'wave-interference', icon: '🌊', title: 'Wave Interference', color: '#6f6' },
      { id: 'entanglement', icon: '🔗', title: 'Entanglement', color: '#f6f' },
      { id: 'supremacy', icon: '⚡', title: 'Supremacy', color: '#f44' },
      { id: 'qec', icon: '🛡️', title: 'Error Correction', color: '#0af' },
    ]
  },
  {
    name: 'Neural',
    modes: [
      { id: 'neural-network', icon: '🧠', title: 'Neural Network', color: '#0af' },
      { id: 'neuromorphic', icon: '🧬', title: 'Neuromorphic', color: '#c4f' },
      { id: 'llm-architecture', icon: '🏗️', title: 'LLM Architecture', color: '#48f' },
    ]
  },
  {
    name: 'Cosmic',
    modes: [
      { id: 'vortex', icon: '🌀', title: 'Vortex', color: '#fa0' },
      { id: 'multiverse', icon: '🌌', title: 'Multiverse', color: '#48f' },
      { id: 'photon-beam', icon: '💫', title: 'Photon Beam', color: '#ff6' },
    ]
  },
  {
    name: 'Mind',
    modes: [
      { id: 'consciousness', icon: '👁️', title: 'Consciousness', color: '#a6f' },
      { id: 'transcendence', icon: '✨', title: 'Transcendence', color: '#ff0' },
      { id: 'beings', icon: '👾', title: 'Digital Beings', color: '#f4a' },
    ]
  },
  {
    name: 'Life',
    modes: [
      { id: 'living', icon: '🌱', title: 'Living Systems', color: '#4f4' },
      { id: 'quantum-life', icon: '🦠', title: 'Quantum Life', color: '#0fa' },
      { id: 'quantum-biology', icon: '🧬', title: 'Quantum Biology', color: '#0fa' },
    ]
  },
  {
    name: 'Security',
    modes: [
      { id: 'encryption', icon: '🔐', title: 'Encryption', color: '#0cf' },
      { id: 'obfuscation', icon: '🎭', title: 'Obfuscation', color: '#a4f' },
      { id: 'secure', icon: '🔒', title: 'Secure Channel', color: '#0fa' },
    ]
  },
  {
    name: 'Russian',
    modes: [
      { id: 'trinity', icon: '🔺', title: 'Trinity', color: '#0e9' },
      { id: 'matryoshka', icon: '🪆', title: 'Matryoshka', color: '#e4a' },
      { id: 'zhar-ptitsa', icon: '🔥', title: 'Zhar-Ptitsa', color: '#f80' },
      { id: 'bogatyri', icon: '⚔️', title: 'Bogatyri 33', color: '#48f' },
    ]
  },
  {
    name: 'Other',
    modes: [
      { id: 'tsp', icon: '🗺️', title: 'TSP Solver', color: '#4a4' },
      { id: 'pas', icon: '📊', title: 'PAS Analysis', color: '#4a4' },
      { id: 'spintronic', icon: '🔄', title: 'Spintronic', color: '#f4a' },
      { id: 'quantum-agents', icon: '🤖', title: 'Quantum Agents', color: '#4af' },
      { id: 'cinema4d', icon: '🎬', title: 'Cinema 4D', color: '#f4a' },
    ]
  },
];

const allModes = categories.flatMap(c => c.modes);

export default function QuantumLab() {
  const [currentMode, setCurrentMode] = useState<VizMode>('quantum-field');
  const [menuOpen, setMenuOpen] = useState(false);
  
  const current = allModes.find(m => m.id === currentMode) || allModes[0];

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000', overflow: 'hidden' }}>
      {/* Fullscreen Canvas */}
      <QuantumCanvas mode={currentMode} particleCount={2000} interactive={true} />
      
      {/* Top Bar */}
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          padding: '1rem 1.5rem',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          zIndex: 100,
          background: 'linear-gradient(to bottom, rgba(0,0,0,0.8), transparent)',
        }}
      >
        <Link to="/" style={{ color: '#fff', textDecoration: 'none', fontWeight: 600, fontSize: '1.1rem' }}>
          TRINITY
        </Link>
        
        <div style={{ color: '#ffd700', fontFamily: 'monospace', fontSize: '0.9rem' }}>
          φ² + 1/φ² = 3
        </div>
      </motion.div>

      {/* Current Mode Info - Bottom Left */}
      <motion.div
        key={currentMode}
        initial={{ opacity: 0, x: -30 }}
        animate={{ opacity: 1, x: 0 }}
        style={{
          position: 'fixed',
          bottom: '2rem',
          left: '2rem',
          zIndex: 100,
        }}
      >
        <div style={{ fontSize: '3rem', marginBottom: '0.5rem', filter: `drop-shadow(0 0 20px ${current.color})` }}>
          {current.icon}
        </div>
        <h1 style={{ fontSize: '2rem', fontWeight: 600, color: '#fff', marginBottom: '0.25rem' }}>
          {current.title}
        </h1>
        <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: '0.9rem' }}>
          Move cursor to interact
        </p>
      </motion.div>

      {/* Menu Button - Bottom Right */}
      <motion.button
        onClick={() => setMenuOpen(!menuOpen)}
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        style={{
          position: 'fixed',
          bottom: '2rem',
          right: '2rem',
          zIndex: 200,
          padding: '1rem 1.5rem',
          background: menuOpen ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.6)',
          backdropFilter: 'blur(20px)',
          border: '1px solid rgba(255,255,255,0.2)',
          borderRadius: '100px',
          color: '#fff',
          cursor: 'pointer',
          fontSize: '1rem',
          fontWeight: 500,
          display: 'flex',
          alignItems: 'center',
          gap: '0.5rem'
        }}
      >
        {menuOpen ? '✕ Close' : '☰ Modes'}
      </motion.button>

      {/* Menu Panel */}
      <AnimatePresence>
        {menuOpen && (
          <motion.div
            initial={{ opacity: 0, x: 300 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 300 }}
            transition={{ type: 'spring', damping: 25 }}
            style={{
              position: 'fixed',
              top: 0,
              right: 0,
              bottom: 0,
              width: 'min(400px, 90vw)',
              background: 'rgba(0,0,0,0.95)',
              backdropFilter: 'blur(30px)',
              borderLeft: '1px solid rgba(255,255,255,0.1)',
              zIndex: 150,
              overflowY: 'auto',
              padding: '2rem 1.5rem',
            }}
          >
            <h2 style={{ color: '#fff', fontSize: '1.5rem', marginBottom: '2rem', fontWeight: 600 }}>
              Visualization Modes
            </h2>
            
            {categories.map(category => (
              <div key={category.name} style={{ marginBottom: '2rem' }}>
                <h3 style={{ 
                  color: 'rgba(255,255,255,0.4)', 
                  fontSize: '0.75rem', 
                  textTransform: 'uppercase', 
                  letterSpacing: '0.1em',
                  marginBottom: '0.75rem'
                }}>
                  {category.name}
                </h3>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                  {category.modes.map(mode => (
                    <motion.button
                      key={mode.id}
                      onClick={() => { setCurrentMode(mode.id as VizMode); setMenuOpen(false); }}
                      whileHover={{ scale: 1.05 }}
                      whileTap={{ scale: 0.95 }}
                      style={{
                        padding: '0.6rem 1rem',
                        background: currentMode === mode.id ? `${mode.color}33` : 'rgba(255,255,255,0.05)',
                        border: `1px solid ${currentMode === mode.id ? mode.color : 'rgba(255,255,255,0.1)'}`,
                        borderRadius: '100px',
                        color: currentMode === mode.id ? mode.color : 'rgba(255,255,255,0.7)',
                        cursor: 'pointer',
                        fontSize: '0.85rem',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '0.4rem',
                        transition: 'all 0.2s'
                      }}
                    >
                      <span>{mode.icon}</span>
                      <span>{mode.title}</span>
                    </motion.button>
                  ))}
                </div>
              </div>
            ))}

            {/* Formula */}
            <div style={{ 
              marginTop: '2rem', 
              padding: '1.5rem', 
              background: 'rgba(255,215,0,0.05)', 
              borderRadius: '12px',
              textAlign: 'center'
            }}>
              <div style={{ color: '#ffd700', fontSize: '1.2rem', fontFamily: 'monospace' }}>
                φ² + 1/φ² = 3
              </div>
              <div style={{ color: '#f66', fontSize: '0.8rem', marginTop: '0.5rem' }}>
                PHOENIX = 999
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Gradient Overlays */}
      <div style={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        height: '150px',
        background: 'linear-gradient(to top, rgba(0,0,0,0.7), transparent)',
        pointerEvents: 'none',
        zIndex: 50
      }} />
    </div>
  );
}
