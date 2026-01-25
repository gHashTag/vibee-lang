"use client";
import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';

const PHI = 1.618033988749895;
const TAU = Math.PI * 2;

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  phase: number;
  amplitude: number;
  hue: number;
  size: number;
}

type Mode = 'quantum' | 'vortex' | 'photon' | 'entangle';

export default function QuantumViz() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [mode, setMode] = useState<Mode>('quantum');
  const [params, setParams] = useState({
    superposition: 0.5,
    entanglement: 0.7,
    particles: 2000,
    decay: 0.02
  });
  const [fps, setFps] = useState(0);
  const [energy, setEnergy] = useState(0);
  
  const particlesRef = useRef<Particle[]>([]);
  const mouseRef = useRef({ x: 0, y: 0, down: false });
  const timeRef = useRef(0);
  const animationRef = useRef<number | undefined>(undefined);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const resize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };
    resize();
    window.addEventListener('resize', resize);

    // Initialize particles
    const initParticles = (count: number) => {
      particlesRef.current = [];
      for (let i = 0; i < count; i++) {
        particlesRef.current.push({
          x: Math.random() * canvas.width,
          y: Math.random() * canvas.height,
          vx: (Math.random() - 0.5) * 2,
          vy: (Math.random() - 0.5) * 2,
          phase: Math.random() * TAU,
          amplitude: 0.5 + Math.random() * 0.5,
          hue: 140 + Math.random() * 40, // Green-cyan range for TRINITY
          size: 1 + Math.random() * 2
        });
      }
    };
    initParticles(params.particles);

    let lastTime = performance.now();
    let frameCount = 0;
    let fpsTime = 0;

    const animate = (currentTime: number) => {
      const dt = Math.min((currentTime - lastTime) / 1000, 0.1);
      lastTime = currentTime;
      timeRef.current += dt;

      // FPS calculation
      frameCount++;
      fpsTime += dt;
      if (fpsTime >= 1) {
        setFps(Math.round(frameCount / fpsTime));
        frameCount = 0;
        fpsTime = 0;
      }

      // Clear with trail effect
      ctx.fillStyle = 'rgba(0, 0, 0, 0.1)';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      const cx = canvas.width / 2;
      const cy = canvas.height / 2;
      let totalEnergy = 0;

      // Update and draw particles
      particlesRef.current.forEach((p, i) => {
        // Physics based on mode
        if (mode === 'quantum') {
          const wave1 = Math.sin(p.x * 0.01 + timeRef.current * PHI) * params.superposition;
          const wave2 = Math.cos(p.y * 0.01 + timeRef.current) * params.entanglement;
          p.vx += (wave1 + wave2) * dt * 10;
          p.vy += (wave2 - wave1) * dt * 10;
        } else if (mode === 'vortex') {
          const dx = cx - p.x;
          const dy = cy - p.y;
          const d = Math.sqrt(dx * dx + dy * dy) + 1;
          p.vx += (-dy / d * 2 + dx / d * 0.3) * dt;
          p.vy += (dx / d * 2 + dy / d * 0.3) * dt;
        } else if (mode === 'photon') {
          const dx = cx - p.x;
          const dy = cy - p.y;
          const d = Math.sqrt(dx * dx + dy * dy) + 1;
          p.vx += dx / d * 30 / d * dt;
          p.vy += dy / d * 30 / d * dt;
        } else if (mode === 'entangle') {
          // Entangled pairs
          const pair = particlesRef.current[(i + particlesRef.current.length / 2) % particlesRef.current.length];
          const dx = pair.x - p.x;
          const dy = pair.y - p.y;
          const d = Math.sqrt(dx * dx + dy * dy) + 1;
          p.vx += dx / d * params.entanglement * dt * 5;
          p.vy += dy / d * params.entanglement * dt * 5;
        }

        // Mouse interaction
        if (mouseRef.current.down) {
          const dx = mouseRef.current.x - p.x;
          const dy = mouseRef.current.y - p.y;
          const d = Math.sqrt(dx * dx + dy * dy) + 1;
          if (d < 200) {
            p.vx += dx / d * 50 / d * dt;
            p.vy += dy / d * 50 / d * dt;
          }
        }

        // Friction and movement
        p.vx *= 0.99;
        p.vy *= 0.99;
        p.x += p.vx;
        p.y += p.vy;
        p.phase += dt * PHI;
        p.amplitude *= (1 - params.decay * dt);

        // Reset if too faded
        if (p.amplitude < 0.05) {
          p.x = Math.random() * canvas.width;
          p.y = Math.random() * canvas.height;
          p.amplitude = 0.5 + Math.random() * 0.5;
        }

        // Boundary bounce
        if (p.x < 0 || p.x > canvas.width) p.vx *= -0.8;
        if (p.y < 0 || p.y > canvas.height) p.vy *= -0.8;
        p.x = Math.max(0, Math.min(canvas.width, p.x));
        p.y = Math.max(0, Math.min(canvas.height, p.y));

        // Calculate energy
        totalEnergy += p.vx * p.vx + p.vy * p.vy;

        // Draw
        const alpha = p.amplitude * (0.3 + Math.sin(p.phase) * 0.2);
        ctx.fillStyle = `hsla(${p.hue}, 100%, 60%, ${alpha})`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size + p.amplitude * 2, 0, TAU);
        ctx.fill();

        // Draw connections for entangle mode
        if (mode === 'entangle' && i < particlesRef.current.length / 2) {
          const pair = particlesRef.current[i + particlesRef.current.length / 2];
          const d = Math.sqrt((pair.x - p.x) ** 2 + (pair.y - p.y) ** 2);
          if (d < 200) {
            ctx.strokeStyle = `hsla(${p.hue}, 100%, 60%, ${0.1 * (1 - d / 200)})`;
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(pair.x, pair.y);
            ctx.stroke();
          }
        }
      });

      setEnergy(Math.round(totalEnergy));

      // Draw center glow
      const gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, 200);
      gradient.addColorStop(0, 'rgba(0, 229, 153, 0.1)');
      gradient.addColorStop(1, 'transparent');
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      // Draw formula
      ctx.fillStyle = 'rgba(255, 215, 0, 0.3)';
      ctx.font = '24px monospace';
      ctx.textAlign = 'center';
      ctx.fillText('φ² + 1/φ² = 3', cx, cy);

      animationRef.current = requestAnimationFrame(animate);
    };

    animationRef.current = requestAnimationFrame(animate);

    // Mouse handlers
    const handleMouseMove = (e: MouseEvent) => {
      mouseRef.current.x = e.clientX;
      mouseRef.current.y = e.clientY;
    };
    const handleMouseDown = () => { mouseRef.current.down = true; };
    const handleMouseUp = () => { mouseRef.current.down = false; };

    canvas.addEventListener('mousemove', handleMouseMove);
    canvas.addEventListener('mousedown', handleMouseDown);
    canvas.addEventListener('mouseup', handleMouseUp);
    canvas.addEventListener('touchstart', (e) => {
      mouseRef.current.down = true;
      mouseRef.current.x = e.touches[0].clientX;
      mouseRef.current.y = e.touches[0].clientY;
    });
    canvas.addEventListener('touchmove', (e) => {
      mouseRef.current.x = e.touches[0].clientX;
      mouseRef.current.y = e.touches[0].clientY;
    });
    canvas.addEventListener('touchend', () => { mouseRef.current.down = false; });

    return () => {
      window.removeEventListener('resize', resize);
      canvas.removeEventListener('mousemove', handleMouseMove);
      canvas.removeEventListener('mousedown', handleMouseDown);
      canvas.removeEventListener('mouseup', handleMouseUp);
      if (animationRef.current) cancelAnimationFrame(animationRef.current);
    };
  }, [mode, params]);

  // Reinitialize particles when count changes
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    particlesRef.current = [];
    for (let i = 0; i < params.particles; i++) {
      particlesRef.current.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        vx: (Math.random() - 0.5) * 2,
        vy: (Math.random() - 0.5) * 2,
        phase: Math.random() * TAU,
        amplitude: 0.5 + Math.random() * 0.5,
        hue: 140 + Math.random() * 40,
        size: 1 + Math.random() * 2
      });
    }
  }, [params.particles]);

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000' }}>
      <canvas ref={canvasRef} style={{ display: 'block' }} />
      
      {/* Control Panel */}
      <motion.div 
        initial={{ x: -300 }}
        animate={{ x: 0 }}
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          width: '280px',
          height: '100vh',
          background: 'rgba(10, 10, 18, 0.95)',
          backdropFilter: 'blur(20px)',
          padding: '20px',
          overflowY: 'auto',
          borderRight: '1px solid rgba(255,255,255,0.1)'
        }}
      >
        <a href="/" style={{ color: 'var(--muted)', textDecoration: 'none', fontSize: '0.8rem', display: 'block', marginBottom: '1rem' }}>
          ← Back to TRINITY
        </a>
        
        <h1 style={{ fontSize: '1.2rem', color: '#ffd700', marginBottom: '1.5rem' }}>
          Quantum Visualization
        </h1>

        {/* Mode Selection */}
        <div style={{ background: '#111', borderRadius: '8px', padding: '12px', marginBottom: '12px' }}>
          <h3 style={{ fontSize: '0.75rem', color: '#0af', marginBottom: '10px' }}>Mode</h3>
          {(['quantum', 'vortex', 'photon', 'entangle'] as Mode[]).map(m => (
            <button
              key={m}
              onClick={() => setMode(m)}
              style={{
                display: 'block',
                width: '100%',
                padding: '10px',
                margin: '4px 0',
                background: mode === m ? 'rgba(255, 215, 0, 0.2)' : '#222',
                border: `1px solid ${mode === m ? '#ffd700' : '#333'}`,
                borderRadius: '6px',
                color: '#fff',
                cursor: 'pointer',
                fontSize: '0.8rem',
                textTransform: 'capitalize'
              }}
            >
              {m === 'quantum' && '⚛️ '}{m === 'vortex' && '🌀 '}{m === 'photon' && '✨ '}{m === 'entangle' && '🔗 '}
              {m}
            </button>
          ))}
        </div>

        {/* Quantum Parameters */}
        <div style={{ background: '#111', borderRadius: '8px', padding: '12px', marginBottom: '12px' }}>
          <h3 style={{ fontSize: '0.75rem', color: '#0af', marginBottom: '10px' }}>Quantum</h3>
          
          <div style={{ marginBottom: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', color: '#888' }}>
              <span>Superposition</span>
              <span>{params.superposition.toFixed(2)}</span>
            </div>
            <input
              type="range"
              min="0"
              max="1"
              step="0.01"
              value={params.superposition}
              onChange={e => setParams(p => ({ ...p, superposition: parseFloat(e.target.value) }))}
              style={{ width: '100%' }}
            />
          </div>

          <div style={{ marginBottom: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', color: '#888' }}>
              <span>Entanglement</span>
              <span>{params.entanglement.toFixed(2)}</span>
            </div>
            <input
              type="range"
              min="0"
              max="1"
              step="0.01"
              value={params.entanglement}
              onChange={e => setParams(p => ({ ...p, entanglement: parseFloat(e.target.value) }))}
              style={{ width: '100%' }}
            />
          </div>
        </div>

        {/* Physics */}
        <div style={{ background: '#111', borderRadius: '8px', padding: '12px', marginBottom: '12px' }}>
          <h3 style={{ fontSize: '0.75rem', color: '#0af', marginBottom: '10px' }}>Physics</h3>
          
          <div style={{ marginBottom: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', color: '#888' }}>
              <span>Particles</span>
              <span>{params.particles}</span>
            </div>
            <input
              type="range"
              min="500"
              max="5000"
              step="100"
              value={params.particles}
              onChange={e => setParams(p => ({ ...p, particles: parseInt(e.target.value) }))}
              style={{ width: '100%' }}
            />
          </div>

          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', color: '#888' }}>
              <span>Decay</span>
              <span>{params.decay.toFixed(3)}</span>
            </div>
            <input
              type="range"
              min="0"
              max="0.1"
              step="0.005"
              value={params.decay}
              onChange={e => setParams(p => ({ ...p, decay: parseFloat(e.target.value) }))}
              style={{ width: '100%' }}
            />
          </div>
        </div>

        {/* Stats */}
        <div style={{ fontSize: '0.7rem', color: '#888', marginTop: '20px' }}>
          FPS: <span style={{ color: '#0f0' }}>{fps}</span><br />
          Energy: <span style={{ color: '#0f0' }}>{energy}</span><br />
          Mode: <span style={{ color: '#ffd700' }}>{mode}</span>
        </div>

        {/* Formula */}
        <div style={{ textAlign: 'center', marginTop: '20px' }}>
          <div style={{ color: '#ffd700', fontSize: '1rem' }}>φ² + 1/φ² = 3</div>
          <div style={{ color: '#f66', fontSize: '0.8rem' }}>PHOENIX = 999</div>
        </div>
      </motion.div>

      {/* Instructions */}
      <div style={{
        position: 'fixed',
        bottom: '20px',
        right: '20px',
        background: 'rgba(0,0,0,0.8)',
        padding: '12px 16px',
        borderRadius: '8px',
        fontSize: '0.75rem',
        color: 'var(--muted)'
      }}>
        Click and drag to interact with particles
      </div>
    </div>
  );
}
