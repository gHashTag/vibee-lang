"use client";
import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link } from 'react-router-dom';
import QuantumCanvas from '../components/QuantumCanvas';
import type { VizMode } from '../components/QuantumCanvas';

const categories = [
  {
    name: 'TRINITY',
    modes: [
      { id: 'trinity-computer', icon: '🔮', title: 'TRINITY Computer', color: '#ffd700' },
      { id: 'trinity', icon: '🔺', title: 'Trinity Core', color: '#0e9' },
    ]
  },
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
  const [currentMode, setCurrentMode] = useState<VizMode>('trinity-computer');
  const [menuOpen, setMenuOpen] = useState(false);
  
  const current = allModes.find(m => m.id === currentMode) || allModes[0];

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000', overflow: 'hidden' }}>
      {/* Fullscreen Canvas */}
      <QuantumCanvas mode={currentMode} particleCount={2000} interactive={true} />
      
      {/* Top Left - Logo */}
      <motion.div
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        style={{
          position: 'fixed',
          top: '1.5rem',
          left: '1.5rem',
          zIndex: 100,
        }}
      >
        <Link to="/" style={{ 
          color: '#fff', 
          textDecoration: 'none', 
          fontWeight: 600, 
          fontSize: '1.1rem',
          padding: '0.5rem 1rem',
          background: 'rgba(0,0,0,0.5)',
          backdropFilter: 'blur(10px)',
          borderRadius: '8px',
          border: '1px solid rgba(255,255,255,0.1)',
        }}>
          ← TRINITY
        </Link>
      </motion.div>

      {/* Top Right - Menu Button */}
      <motion.button
        onClick={() => setMenuOpen(!menuOpen)}
        initial={{ opacity: 0, x: 20 }}
        animate={{ opacity: 1, x: 0 }}
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        style={{
          position: 'fixed',
          top: '1.5rem',
          right: '1.5rem',
          zIndex: 200,
          padding: '0.75rem 1.25rem',
          background: menuOpen ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.6)',
          backdropFilter: 'blur(20px)',
          border: '1px solid rgba(255,255,255,0.2)',
          borderRadius: '100px',
          color: '#fff',
          cursor: 'pointer',
          fontSize: '0.9rem',
          fontWeight: 500,
          display: 'flex',
          alignItems: 'center',
          gap: '0.5rem'
        }}
      >
        {menuOpen ? '✕ Close' : '☰ Modes'}
      </motion.button>

      {/* Bottom Center - Current Mode Info */}
      <motion.div
        key={currentMode}
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        style={{
          position: 'fixed',
          bottom: '2rem',
          left: '50%',
          transform: 'translateX(-50%)',
          zIndex: 100,
          textAlign: 'center',
          padding: '1rem 2rem',
          background: 'rgba(0,0,0,0.5)',
          backdropFilter: 'blur(10px)',
          borderRadius: '16px',
          border: '1px solid rgba(255,255,255,0.1)',
        }}
      >
        <div style={{ 
          display: 'flex', 
          alignItems: 'center', 
          justifyContent: 'center',
          gap: '0.75rem',
          marginBottom: '0.25rem'
        }}>
          <span style={{ fontSize: '2rem', filter: `drop-shadow(0 0 15px ${current.color})` }}>
            {current.icon}
          </span>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 600, color: '#fff', margin: 0 }}>
            {current.title}
          </h1>
        </div>
        <p style={{ color: 'rgba(255,255,255,0.4)', fontSize: '0.8rem', margin: 0 }}>
          Move cursor to interact • <span style={{ color: '#ffd700' }}>φ² + 1/φ² = 3</span>
        </p>
      </motion.div>

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
              top: '5rem',
              right: '1rem',
              bottom: '1rem',
              width: 'min(360px, calc(100vw - 2rem))',
              background: 'rgba(0,0,0,0.9)',
              backdropFilter: 'blur(30px)',
              border: '1px solid rgba(255,255,255,0.1)',
              borderRadius: '16px',
              zIndex: 150,
              overflowY: 'auto',
              padding: '1.5rem',
            }}
          >
            <h2 style={{ color: '#fff', fontSize: '1.25rem', marginBottom: '1.5rem', fontWeight: 600 }}>
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

      {/* Gradient Overlays - corners */}
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        height: '100px',
        background: 'linear-gradient(to bottom, rgba(0,0,0,0.6), transparent)',
        pointerEvents: 'none',
        zIndex: 50
      }} />
      <div style={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        height: '120px',
        background: 'linear-gradient(to top, rgba(0,0,0,0.6), transparent)',
        pointerEvents: 'none',
        zIndex: 50
      }} />
    </div>
  );
}
