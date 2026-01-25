"use client";
import { useEffect, useRef } from 'react';

const PHI = 1.618033988749895;
const TAU = Math.PI * 2;

export type VizMode = 'quantum-field' | 'neural-network' | 'wave-interference' | 'entanglement' | 'vortex' | 'photon-beam';

interface Particle {
  x: number; y: number;
  vx: number; vy: number;
  phase: number; amplitude: number;
  hue: number; size: number;
  spin: number;
  entangledWith: number | null;
  layer: number;
}

interface QuantumCanvasProps {
  mode: VizMode;
  particleCount?: number;
  interactive?: boolean;
}

export default function QuantumCanvas({ mode, particleCount = 1500, interactive = true }: QuantumCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
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
      canvas.width = canvas.offsetWidth * window.devicePixelRatio;
      canvas.height = canvas.offsetHeight * window.devicePixelRatio;
      ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
    };
    resize();
    window.addEventListener('resize', resize);

    const W = () => canvas.offsetWidth;
    const H = () => canvas.offsetHeight;

    // Initialize particles
    particlesRef.current = [];
    for (let i = 0; i < particleCount; i++) {
      particlesRef.current.push({
        x: Math.random() * W(),
        y: Math.random() * H(),
        vx: (Math.random() - 0.5) * 2,
        vy: (Math.random() - 0.5) * 2,
        phase: Math.random() * TAU,
        amplitude: 0.3 + Math.random() * 0.7,
        hue: mode === 'neural-network' ? 200 + Math.random() * 60 : 140 + Math.random() * 40,
        size: 1 + Math.random() * 2,
        spin: Math.random() > 0.5 ? 1 : -1,
        entangledWith: null,
        layer: Math.floor(Math.random() * 3)
      });
    }

    // Entangle pairs
    if (mode === 'entanglement') {
      for (let i = 0; i < particlesRef.current.length / 2; i++) {
        particlesRef.current[i].entangledWith = i + Math.floor(particlesRef.current.length / 2);
        particlesRef.current[i + Math.floor(particlesRef.current.length / 2)].entangledWith = i;
      }
    }

    let lastTime = performance.now();

    const animate = (currentTime: number) => {
      const dt = Math.min((currentTime - lastTime) / 1000, 0.1);
      lastTime = currentTime;
      timeRef.current += dt;

      const w = W();
      const h = H();
      const cx = w / 2;
      const cy = h / 2;

      // Clear with trail
      ctx.fillStyle = mode === 'photon-beam' ? 'rgba(0, 0, 0, 0.03)' : 'rgba(0, 0, 0, 0.08)';
      ctx.fillRect(0, 0, w, h);

      // Wave interference background
      if (mode === 'wave-interference') {
        const imageData = ctx.getImageData(0, 0, w, h);
        const data = imageData.data;
        for (let y = 0; y < h; y += 3) {
          for (let x = 0; x < w; x += 3) {
            let wave = 0;
            const sources = [[cx - 100, cy], [cx + 100, cy]];
            sources.forEach(([sx, sy]) => {
              const dx = x - sx;
              const dy = y - sy;
              const r = Math.sqrt(dx * dx + dy * dy);
              wave += Math.sin(r * 0.05 - timeRef.current * 3) * Math.exp(-r * 0.002);
            });
            const intensity = (wave + 1) * 40;
            const idx = (y * w + x) * 4;
            data[idx] = Math.min(255, intensity * 0.2);
            data[idx + 1] = Math.min(255, intensity * 0.8);
            data[idx + 2] = Math.min(255, intensity * 0.6);
          }
        }
        ctx.putImageData(imageData, 0, 0);
      }

      // Update and draw particles
      particlesRef.current.forEach((p, i) => {
        // Physics based on mode
        switch (mode) {
          case 'quantum-field': {
            const wave1 = Math.sin(p.x * 0.008 + timeRef.current * PHI) * 0.5;
            const wave2 = Math.cos(p.y * 0.008 + timeRef.current) * 0.5;
            p.vx += (wave1 + wave2) * dt * 8;
            p.vy += (wave2 - wave1) * dt * 8;
            break;
          }
          case 'neural-network': {
            // Layered attraction
            const targetX = cx + (p.layer - 1) * 150;
            const dx = targetX - p.x;
            const dy = cy - p.y + Math.sin(timeRef.current + i * 0.1) * 50;
            p.vx += dx * 0.001;
            p.vy += dy * 0.001;
            break;
          }
          case 'wave-interference': {
            const angle = Math.atan2(p.y - cy, p.x - cx);
            const r = Math.sqrt((p.x - cx) ** 2 + (p.y - cy) ** 2);
            p.vx = Math.cos(angle + 0.02) * r * 0.01;
            p.vy = Math.sin(angle + 0.02) * r * 0.01;
            break;
          }
          case 'entanglement': {
            if (p.entangledWith !== null) {
              const pair = particlesRef.current[p.entangledWith];
              const dx = pair.x - p.x;
              const dy = pair.y - p.y;
              const d = Math.sqrt(dx * dx + dy * dy) + 1;
              p.vx += dx / d * 0.5 * dt * 5;
              p.vy += dy / d * 0.5 * dt * 5;
              p.spin = -pair.spin;
            }
            // Also add some random motion
            p.vx += (Math.random() - 0.5) * dt * 2;
            p.vy += (Math.random() - 0.5) * dt * 2;
            break;
          }
          case 'vortex': {
            const dx = cx - p.x;
            const dy = cy - p.y;
            const d = Math.sqrt(dx * dx + dy * dy) + 1;
            p.vx += (-dy / d * 3 + dx / d * 0.2) * dt;
            p.vy += (dx / d * 3 + dy / d * 0.2) * dt;
            break;
          }
          case 'photon-beam': {
            const angle = Math.atan2(p.y - cy, p.x - cx);
            p.vx = Math.cos(angle) * 3;
            p.vy = Math.sin(angle) * 3;
            break;
          }
        }

        // Mouse interaction
        if (interactive && mouseRef.current.down) {
          const dx = mouseRef.current.x - p.x;
          const dy = mouseRef.current.y - p.y;
          const d = Math.sqrt(dx * dx + dy * dy) + 1;
          if (d < 150) {
            p.vx += dx / d * 30 / d * dt;
            p.vy += dy / d * 30 / d * dt;
          }
        }

        // Physics
        p.vx *= 0.98;
        p.vy *= 0.98;
        p.x += p.vx;
        p.y += p.vy;
        p.phase += dt * PHI * p.spin;
        p.amplitude *= 0.999;

        // Reset faded particles
        if (p.amplitude < 0.1 || p.x < -50 || p.x > w + 50 || p.y < -50 || p.y > h + 50) {
          if (mode === 'photon-beam') {
            p.x = cx + (Math.random() - 0.5) * 20;
            p.y = cy + (Math.random() - 0.5) * 20;
          } else {
            p.x = Math.random() * w;
            p.y = Math.random() * h;
          }
          p.amplitude = 0.3 + Math.random() * 0.7;
          p.phase = Math.random() * TAU;
        }

        // Boundaries for non-beam modes
        if (mode !== 'photon-beam') {
          if (p.x < 0 || p.x > w) p.vx *= -0.8;
          if (p.y < 0 || p.y > h) p.vy *= -0.8;
          p.x = Math.max(0, Math.min(w, p.x));
          p.y = Math.max(0, Math.min(h, p.y));
        }

        // Draw particle
        const alpha = p.amplitude * (0.4 + Math.sin(p.phase) * 0.2);
        const hue = mode === 'entanglement' && p.entangledWith !== null 
          ? (p.spin > 0 ? 0 : 200) 
          : p.hue;
        
        ctx.fillStyle = `hsla(${hue}, 100%, 60%, ${alpha})`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size + p.amplitude * 2, 0, TAU);
        ctx.fill();

        // Draw connections for neural network
        if (mode === 'neural-network' && i < particlesRef.current.length - 1) {
          const next = particlesRef.current.find(np => np.layer === p.layer + 1 && Math.abs(np.y - p.y) < 100);
          if (next) {
            const d = Math.sqrt((next.x - p.x) ** 2 + (next.y - p.y) ** 2);
            if (d < 200) {
              ctx.strokeStyle = `hsla(${p.hue}, 100%, 60%, ${0.1 * (1 - d / 200)})`;
              ctx.beginPath();
              ctx.moveTo(p.x, p.y);
              ctx.lineTo(next.x, next.y);
              ctx.stroke();
            }
          }
        }

        // Draw entanglement lines
        if (mode === 'entanglement' && p.entangledWith !== null && i < particlesRef.current.length / 2) {
          const pair = particlesRef.current[p.entangledWith];
          const d = Math.sqrt((pair.x - p.x) ** 2 + (pair.y - p.y) ** 2);
          if (d < 400) {
            ctx.strokeStyle = `hsla(280, 100%, 60%, ${0.15 * (1 - d / 400)})`;
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(pair.x, pair.y);
            ctx.stroke();
          }
        }
      });

      // Center glow
      const gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, 150);
      gradient.addColorStop(0, 'rgba(0, 229, 153, 0.1)');
      gradient.addColorStop(1, 'transparent');
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, w, h);

      animationRef.current = requestAnimationFrame(animate);
    };

    animationRef.current = requestAnimationFrame(animate);

    // Event handlers
    const handleMouseMove = (e: MouseEvent) => {
      const rect = canvas.getBoundingClientRect();
      mouseRef.current.x = e.clientX - rect.left;
      mouseRef.current.y = e.clientY - rect.top;
    };
    const handleMouseDown = () => { mouseRef.current.down = true; };
    const handleMouseUp = () => { mouseRef.current.down = false; };
    const handleTouch = (e: TouchEvent) => {
      const rect = canvas.getBoundingClientRect();
      mouseRef.current.x = e.touches[0]?.clientX - rect.left || mouseRef.current.x;
      mouseRef.current.y = e.touches[0]?.clientY - rect.top || mouseRef.current.y;
    };

    if (interactive) {
      canvas.addEventListener('mousemove', handleMouseMove);
      canvas.addEventListener('mousedown', handleMouseDown);
      canvas.addEventListener('mouseup', handleMouseUp);
      canvas.addEventListener('touchstart', (e) => { mouseRef.current.down = true; handleTouch(e); });
      canvas.addEventListener('touchmove', handleTouch);
      canvas.addEventListener('touchend', () => { mouseRef.current.down = false; });
    }

    return () => {
      window.removeEventListener('resize', resize);
      if (animationRef.current) cancelAnimationFrame(animationRef.current);
    };
  }, [mode, particleCount, interactive]);

  return (
    <canvas 
      ref={canvasRef} 
      style={{ 
        width: '100%', 
        height: '100%', 
        display: 'block',
        cursor: interactive ? 'crosshair' : 'default'
      }} 
    />
  );
}
