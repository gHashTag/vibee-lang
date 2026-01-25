"use client";
import { useEffect, useRef, useState, useCallback } from 'react';
import { motion } from 'framer-motion';

const PHI = 1.618033988749895;
const TAU = Math.PI * 2;

type Mode = 'quantum' | 'vortex' | 'photon' | 'entangle' | 'beam' | 'interference' | 'soliton';

interface Particle {
  x: number; y: number;
  vx: number; vy: number;
  phase: number; amplitude: number;
  hue: number; size: number;
  spin: number; wavelength: number;
  entangledWith: number | null;
}

export default function QuantumViz() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [mode, setMode] = useState<Mode>('quantum');
  const [params, setParams] = useState({
    superposition: 0.5,
    entanglement: 0.7,
    particles: 2000,
    decay: 0.02,
    wavelength: 100,
    coherence: 0.8
  });
  const [fps, setFps] = useState(0);
  const [energy, setEnergy] = useState(0);
  const [audioEnabled, setAudioEnabled] = useState(false);
  
  const particlesRef = useRef<Particle[]>([]);
  const mouseRef = useRef({ x: 0, y: 0, down: false });
  const timeRef = useRef(0);
  const animationRef = useRef<number | undefined>(undefined);
  const audioCtxRef = useRef<AudioContext | null>(null);

  const initAudio = useCallback(() => {
    if (audioCtxRef.current) return;
    audioCtxRef.current = new AudioContext();
    const freqs = [220, 277.18, 329.63, 392, 440, 523.25, 659.25, 783.99];
    freqs.forEach(f => {
      const osc = audioCtxRef.current!.createOscillator();
      const gain = audioCtxRef.current!.createGain();
      osc.type = 'sine';
      osc.frequency.value = f * PHI;
      gain.gain.value = 0;
      osc.connect(gain);
      gain.connect(audioCtxRef.current!.destination);
      osc.start();
    });
  }, []);

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
        size: 1 + Math.random() * 2,
        spin: Math.random() > 0.5 ? 1 : -1,
        wavelength: 50 + Math.random() * 100,
        entangledWith: null
      });
    }

    // Entangle pairs
    for (let i = 0; i < particlesRef.current.length / 2; i++) {
      particlesRef.current[i].entangledWith = i + Math.floor(particlesRef.current.length / 2);
      particlesRef.current[i + Math.floor(particlesRef.current.length / 2)].entangledWith = i;
    }

    let lastTime = performance.now();
    let frameCount = 0;
    let fpsTime = 0;

    const animate = (currentTime: number) => {
      const dt = Math.min((currentTime - lastTime) / 1000, 0.1);
      lastTime = currentTime;
      timeRef.current += dt;

      frameCount++;
      fpsTime += dt;
      if (fpsTime >= 1) {
        setFps(Math.round(frameCount / fpsTime));
        frameCount = 0;
        fpsTime = 0;
      }

      // Trail effect
      ctx.fillStyle = mode === 'beam' ? 'rgba(0, 0, 0, 0.05)' : 'rgba(0, 0, 0, 0.1)';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      const cx = canvas.width / 2;
      const cy = canvas.height / 2;
      let totalEnergy = 0;

      // Draw interference pattern for beam mode
      if (mode === 'beam' || mode === 'interference') {
        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const data = imageData.data;
        
        for (let y = 0; y < canvas.height; y += 4) {
          for (let x = 0; x < canvas.width; x += 4) {
            let wave = 0;
            particlesRef.current.slice(0, 20).forEach(p => {
              const dx = x - p.x;
              const dy = y - p.y;
              const r = Math.sqrt(dx * dx + dy * dy);
              const k = TAU / p.wavelength;
              wave += p.amplitude * Math.cos(k * r - timeRef.current * PHI + p.phase) * Math.exp(-params.decay * r * 0.01);
            });
            
            const intensity = Math.abs(wave) * 50;
            const idx = (y * canvas.width + x) * 4;
            data[idx] = Math.min(255, data[idx] + intensity * 0.2);
            data[idx + 1] = Math.min(255, data[idx + 1] + intensity * 0.9);
            data[idx + 2] = Math.min(255, data[idx + 2] + intensity * 0.6);
          }
        }
        ctx.putImageData(imageData, 0, 0);
      }

      // Update particles
      particlesRef.current.forEach((p, i) => {
        // Physics based on mode
        switch (mode) {
          case 'quantum': {
            const wave1 = Math.sin(p.x * 0.01 + timeRef.current * PHI) * params.superposition;
            const wave2 = Math.cos(p.y * 0.01 + timeRef.current) * params.entanglement;
            p.vx += (wave1 + wave2) * dt * 10;
            p.vy += (wave2 - wave1) * dt * 10;
            break;
          }
          case 'vortex': {
            const dx1 = cx - p.x;
            const dy1 = cy - p.y;
            const d1 = Math.sqrt(dx1 * dx1 + dy1 * dy1) + 1;
            p.vx += (-dy1 / d1 * 2 + dx1 / d1 * 0.3) * dt;
            p.vy += (dx1 / d1 * 2 + dy1 / d1 * 0.3) * dt;
            break;
          }
          case 'photon': {
            const dx2 = cx - p.x;
            const dy2 = cy - p.y;
            const d2 = Math.sqrt(dx2 * dx2 + dy2 * dy2) + 1;
            p.vx += dx2 / d2 * 30 / d2 * dt;
            p.vy += dy2 / d2 * 30 / d2 * dt;
            break;
          }
          case 'entangle': {
            if (p.entangledWith !== null) {
              const pair = particlesRef.current[p.entangledWith];
              const dx = pair.x - p.x;
              const dy = pair.y - p.y;
              const d = Math.sqrt(dx * dx + dy * dy) + 1;
              p.vx += dx / d * params.entanglement * dt * 5;
              p.vy += dy / d * params.entanglement * dt * 5;
              p.spin = -pair.spin;
            }
            break;
          }
          case 'beam':
          case 'interference': {
            const angle = Math.atan2(p.y - cy, p.x - cx);
            p.vx = Math.cos(angle) * 2;
            p.vy = Math.sin(angle) * 2;
            break;
          }
          case 'soliton': {
            const solitonX = cx + Math.cos(timeRef.current * 0.5) * 200;
            const dxs = solitonX - p.x;
            const dys = cy - p.y;
            const ds = Math.sqrt(dxs * dxs + dys * dys) + 1;
            p.vx += dxs / ds * 0.5 * dt * 10;
            p.vy += dys / ds * 0.1 * dt * 10;
            p.amplitude = 1 / (1 + ds * 0.01);
            break;
          }
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

        // Physics
        p.vx *= 0.99;
        p.vy *= 0.99;
        p.x += p.vx;
        p.y += p.vy;
        p.phase += dt * PHI * p.spin;
        p.amplitude *= (1 - params.decay * dt);

        // Reset faded particles
        if (p.amplitude < 0.05) {
          p.x = mode === 'beam' ? cx : Math.random() * canvas.width;
          p.y = mode === 'beam' ? cy : Math.random() * canvas.height;
          p.amplitude = 0.5 + Math.random() * 0.5;
          p.phase = Math.random() * TAU;
        }

        // Boundaries
        if (p.x < 0 || p.x > canvas.width) p.vx *= -0.8;
        if (p.y < 0 || p.y > canvas.height) p.vy *= -0.8;
        p.x = Math.max(0, Math.min(canvas.width, p.x));
        p.y = Math.max(0, Math.min(canvas.height, p.y));

        totalEnergy += p.vx * p.vx + p.vy * p.vy;

        // Draw particle
        const alpha = p.amplitude * (0.3 + Math.sin(p.phase) * 0.2);
        const hue = mode === 'entangle' && p.entangledWith !== null ? (p.spin > 0 ? 0 : 200) : p.hue;
        ctx.fillStyle = `hsla(${hue}, 100%, 60%, ${alpha})`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size + p.amplitude * 2, 0, TAU);
        ctx.fill();

        // Draw entanglement lines
        if (mode === 'entangle' && p.entangledWith !== null && i < particlesRef.current.length / 2) {
          const pair = particlesRef.current[p.entangledWith];
          const d = Math.sqrt((pair.x - p.x) ** 2 + (pair.y - p.y) ** 2);
          if (d < 300) {
            ctx.strokeStyle = `hsla(280, 100%, 60%, ${0.15 * (1 - d / 300)})`;
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(pair.x, pair.y);
            ctx.stroke();
          }
        }
      });

      setEnergy(Math.round(totalEnergy));

      // Center glow
      const gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, 200);
      gradient.addColorStop(0, 'rgba(0, 229, 153, 0.15)');
      gradient.addColorStop(1, 'transparent');
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      // Formula
      ctx.fillStyle = 'rgba(255, 215, 0, 0.4)';
      ctx.font = '28px monospace';
      ctx.textAlign = 'center';
      ctx.fillText('φ² + 1/φ² = 3', cx, cy);
      ctx.font = '14px monospace';
      ctx.fillStyle = 'rgba(255, 102, 102, 0.4)';
      ctx.fillText('PHOENIX = 999', cx, cy + 30);

      animationRef.current = requestAnimationFrame(animate);
    };

    animationRef.current = requestAnimationFrame(animate);

    // Event handlers
    const handleMouseMove = (e: MouseEvent) => {
      mouseRef.current.x = e.clientX;
      mouseRef.current.y = e.clientY;
    };
    const handleMouseDown = () => { mouseRef.current.down = true; };
    const handleMouseUp = () => { mouseRef.current.down = false; };
    const handleTouch = (e: TouchEvent) => {
      mouseRef.current.x = e.touches[0]?.clientX || mouseRef.current.x;
      mouseRef.current.y = e.touches[0]?.clientY || mouseRef.current.y;
    };

    canvas.addEventListener('mousemove', handleMouseMove);
    canvas.addEventListener('mousedown', handleMouseDown);
    canvas.addEventListener('mouseup', handleMouseUp);
    canvas.addEventListener('touchstart', (e) => { mouseRef.current.down = true; handleTouch(e); });
    canvas.addEventListener('touchmove', handleTouch);
    canvas.addEventListener('touchend', () => { mouseRef.current.down = false; });

    return () => {
      window.removeEventListener('resize', resize);
      if (animationRef.current) cancelAnimationFrame(animationRef.current);
    };
  }, [mode, params.particles, params.superposition, params.entanglement, params.decay]);

  const modes: { id: Mode; icon: string; name: string; desc: string }[] = [
    { id: 'quantum', icon: '⚛️', name: 'Quantum Wave', desc: 'Superposition & interference' },
    { id: 'vortex', icon: '🌀', name: 'Vortex', desc: 'Spiral dynamics' },
    { id: 'photon', icon: '✨', name: 'Photon Field', desc: 'Light attraction' },
    { id: 'entangle', icon: '🔗', name: 'Entanglement', desc: 'Correlated pairs' },
    { id: 'beam', icon: '💫', name: 'Beam Photon', desc: 'Wave propagation' },
    { id: 'interference', icon: '🌊', name: 'Interference', desc: 'Wave patterns' },
    { id: 'soliton', icon: '〰️', name: 'Soliton', desc: 'Stable wave packet' },
  ];

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000' }}>
      <canvas ref={canvasRef} style={{ display: 'block' }} />
      
      <motion.div 
        initial={{ x: -300 }}
        animate={{ x: 0 }}
        style={{
          position: 'fixed', top: 0, left: 0, width: '280px', height: '100vh',
          background: 'rgba(10, 10, 18, 0.95)', backdropFilter: 'blur(20px)',
          padding: '16px', overflowY: 'auto', borderRight: '1px solid rgba(255,255,255,0.1)'
        }}
      >
        <a href="/" style={{ color: '#888', textDecoration: 'none', fontSize: '0.8rem' }}>← Back to TRINITY</a>
        <h1 style={{ fontSize: '1.1rem', color: '#ffd700', margin: '1rem 0' }}>Quantum Visualizations</h1>

        {/* Modes */}
        <div style={{ background: '#111', borderRadius: '8px', padding: '10px', marginBottom: '10px' }}>
          <h3 style={{ fontSize: '0.7rem', color: '#0af', marginBottom: '8px' }}>Mode</h3>
          {modes.map(m => (
            <button key={m.id} onClick={() => setMode(m.id)} style={{
              display: 'block', width: '100%', padding: '8px', margin: '3px 0',
              background: mode === m.id ? 'rgba(255,215,0,0.2)' : '#222',
              border: `1px solid ${mode === m.id ? '#ffd700' : '#333'}`,
              borderRadius: '6px', color: '#fff', cursor: 'pointer', fontSize: '0.75rem', textAlign: 'left'
            }}>
              {m.icon} {m.name}
              <div style={{ fontSize: '0.6rem', color: '#666', marginTop: '2px' }}>{m.desc}</div>
            </button>
          ))}
        </div>

        {/* Parameters */}
        <div style={{ background: '#111', borderRadius: '8px', padding: '10px', marginBottom: '10px' }}>
          <h3 style={{ fontSize: '0.7rem', color: '#0af', marginBottom: '8px' }}>Quantum Parameters</h3>
          
          {[
            { key: 'superposition', label: 'Superposition', min: 0, max: 1, step: 0.01 },
            { key: 'entanglement', label: 'Entanglement', min: 0, max: 1, step: 0.01 },
            { key: 'particles', label: 'Particles', min: 500, max: 5000, step: 100 },
            { key: 'decay', label: 'Decay', min: 0, max: 0.1, step: 0.005 },
          ].map(({ key, label, min, max, step }) => (
            <div key={key} style={{ marginBottom: '10px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.65rem', color: '#888' }}>
                <span>{label}</span>
                <span>{(params as Record<string, number>)[key].toFixed(key === 'particles' ? 0 : 2)}</span>
              </div>
              <input type="range" min={min} max={max} step={step}
                value={(params as Record<string, number>)[key]}
                onChange={e => setParams(p => ({ ...p, [key]: parseFloat(e.target.value) }))}
                style={{ width: '100%' }}
              />
            </div>
          ))}
        </div>

        {/* Audio */}
        <div style={{ background: '#111', borderRadius: '8px', padding: '10px', marginBottom: '10px' }}>
          <button onClick={() => { initAudio(); setAudioEnabled(!audioEnabled); }} style={{
            width: '100%', padding: '8px', background: audioEnabled ? '#0f03' : '#222',
            border: `1px solid ${audioEnabled ? '#0f0' : '#333'}`,
            borderRadius: '6px', color: '#fff', cursor: 'pointer', fontSize: '0.75rem'
          }}>
            🔊 Audio: {audioEnabled ? 'ON' : 'OFF'}
          </button>
        </div>

        {/* Stats */}
        <div style={{ fontSize: '0.65rem', color: '#888', marginTop: '15px' }}>
          FPS: <span style={{ color: '#0f0' }}>{fps}</span><br />
          Energy: <span style={{ color: '#0f0' }}>{energy}</span><br />
          Particles: <span style={{ color: '#ffd700' }}>{params.particles}</span><br />
          Mode: <span style={{ color: '#0af' }}>{mode}</span>
        </div>

        {/* Formula */}
        <div style={{ textAlign: 'center', marginTop: '20px', padding: '15px', background: '#111', borderRadius: '8px' }}>
          <div style={{ color: '#ffd700', fontSize: '1.1rem', fontFamily: 'monospace' }}>φ² + 1/φ² = 3</div>
          <div style={{ color: '#f66', fontSize: '0.8rem', marginTop: '5px' }}>PHOENIX = 999</div>
          <div style={{ color: '#0af', fontSize: '0.6rem', marginTop: '5px' }}>KOSCHEI IS IMMORTAL</div>
        </div>
      </motion.div>

      {/* Instructions */}
      <div style={{
        position: 'fixed', bottom: '20px', right: '20px',
        background: 'rgba(0,0,0,0.8)', padding: '10px 14px', borderRadius: '8px',
        fontSize: '0.7rem', color: '#888'
      }}>
        Click & drag to interact • Switch modes in panel
      </div>
    </div>
  );
}
