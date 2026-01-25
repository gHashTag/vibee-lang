"use client";
import { useEffect, useRef } from 'react';

const PHI = 1.618033988749895;
const TAU = Math.PI * 2;

export type VizMode = 
  | 'trinity-computer' // Main: TRINITY quantum computer architecture
  | 'quantum-field' | 'neural-network' | 'wave-interference' | 'entanglement' | 'vortex' | 'photon-beam'
  | 'consciousness' | 'trinity' | 'multiverse' | 'encryption' | 'supremacy' | 'tsp'
  | 'neuromorphic' | 'spintronic' | 'transcendence' | 'living' | 'quantum-life' | 'quantum-agents'
  | 'matryoshka' | 'zhar-ptitsa' | 'bogatyri' | 'qec' | 'obfuscation' | 'secure'
  | 'beings' | 'pas' | 'quantum-biology' | 'llm-architecture' | 'cinema4d';

interface Particle {
  x: number; y: number;
  vx: number; vy: number;
  phase: number; amplitude: number;
  hue: number; size: number;
  spin: number;
  entangledWith: number | null;
  layer: number;
  life: number;
  type: number;
}

interface QuantumCanvasProps {
  mode: VizMode;
  particleCount?: number;
  interactive?: boolean;
}

export default function QuantumCanvas({ mode, particleCount = 1500, interactive = true }: QuantumCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const particlesRef = useRef<Particle[]>([]);
  const mouseRef = useRef({ x: 0, y: 0, active: false });
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
    const initParticles = () => {
      particlesRef.current = [];
      for (let i = 0; i < particleCount; i++) {
        particlesRef.current.push({
          x: Math.random() * canvas.width,
          y: Math.random() * canvas.height,
          vx: (Math.random() - 0.5) * 2,
          vy: (Math.random() - 0.5) * 2,
          phase: Math.random() * TAU,
          amplitude: 0.3 + Math.random() * 0.7,
          hue: getHueForMode(mode) + Math.random() * 40 - 20,
          size: 1 + Math.random() * 2,
          spin: Math.random() > 0.5 ? 1 : -1,
          entangledWith: null,
          layer: Math.floor(Math.random() * 5),
          life: 1,
          type: Math.floor(Math.random() * 3)
        });
      }
      // Entangle pairs
      for (let i = 0; i < particlesRef.current.length / 2; i++) {
        particlesRef.current[i].entangledWith = i + Math.floor(particlesRef.current.length / 2);
        particlesRef.current[i + Math.floor(particlesRef.current.length / 2)].entangledWith = i;
      }
    };
    initParticles();

    function getHueForMode(m: VizMode): number {
      const hues: Record<string, number> = {
        'trinity-computer': 160,
        'quantum-field': 160, 'neural-network': 220, 'wave-interference': 120,
        'entanglement': 280, 'vortex': 30, 'photon-beam': 50,
        'consciousness': 270, 'trinity': 160, 'multiverse': 200,
        'encryption': 180, 'supremacy': 0, 'tsp': 100,
        'neuromorphic': 300, 'spintronic': 340, 'transcendence': 60,
        'living': 90, 'quantum-life': 150, 'quantum-agents': 210,
        'matryoshka': 20, 'zhar-ptitsa': 40, 'bogatyri': 240,
        'qec': 190, 'obfuscation': 260, 'secure': 170,
        'beings': 310, 'pas': 130, 'quantum-biology': 140,
        'llm-architecture': 230, 'cinema4d': 350
      };
      return hues[m] || 160;
    }

    // Draw TRINITY Quantum Computer Architecture
    function drawTrinityComputer(ctx: CanvasRenderingContext2D, w: number, h: number, t: number) {
      const cx = w / 2;
      const cy = h / 2;
      const scale = Math.min(w, h) / 800;

      // Background grid
      ctx.strokeStyle = 'rgba(0, 229, 153, 0.05)';
      ctx.lineWidth = 1;
      for (let x = 0; x < w; x += 50) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, h);
        ctx.stroke();
      }
      for (let y = 0; y < h; y += 50) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
        ctx.stroke();
      }

      // === CENTRAL TRINITY CORE ===
      const coreRadius = 120 * scale;
      
      // Outer rotating ring
      ctx.strokeStyle = 'rgba(0, 229, 153, 0.3)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(cx, cy, coreRadius + 40, 0, TAU);
      ctx.stroke();

      // Three main nodes: Physical, Protocol, Intelligence
      const nodes = [
        { name: 'PHYSICAL', color: '#8a2be2', desc: 'Ternary Hardware' },
        { name: 'PROTOCOL', color: '#00ffff', desc: 'Quantum Network' },
        { name: 'INTELLIGENCE', color: '#ff00ff', desc: 'AI/ML Layer' }
      ];

      for (let i = 0; i < 3; i++) {
        const angle = (i * TAU / 3) - Math.PI / 2 + t * 0.3;
        const x = cx + coreRadius * Math.cos(angle);
        const y = cy + coreRadius * Math.sin(angle);

        // Node glow
        const grad = ctx.createRadialGradient(x, y, 0, x, y, 50 * scale);
        grad.addColorStop(0, nodes[i].color + '40');
        grad.addColorStop(1, 'transparent');
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(x, y, 50 * scale, 0, TAU);
        ctx.fill();

        // Node circle
        ctx.fillStyle = nodes[i].color + '80';
        ctx.beginPath();
        ctx.arc(x, y, 35 * scale, 0, TAU);
        ctx.fill();
        ctx.strokeStyle = nodes[i].color;
        ctx.lineWidth = 2;
        ctx.stroke();

        // Node text
        ctx.fillStyle = '#fff';
        ctx.font = `bold ${12 * scale}px monospace`;
        ctx.textAlign = 'center';
        ctx.fillText(nodes[i].name, x, y);
        ctx.font = `${9 * scale}px monospace`;
        ctx.fillStyle = 'rgba(255,255,255,0.6)';
        ctx.fillText(nodes[i].desc, x, y + 14 * scale);

        // Connection to next node
        const nextAngle = ((i + 1) % 3 * TAU / 3) - Math.PI / 2 + t * 0.3;
        const x2 = cx + coreRadius * Math.cos(nextAngle);
        const y2 = cy + coreRadius * Math.sin(nextAngle);
        
        ctx.strokeStyle = 'rgba(138, 43, 226, 0.4)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x2, y2);
        ctx.stroke();

        // Data flow particles on connections
        for (let p = 0; p < 3; p++) {
          const progress = ((t * 0.5 + p * 0.33 + i * 0.1) % 1);
          const px = x + (x2 - x) * progress;
          const py = y + (y2 - y) * progress;
          ctx.fillStyle = nodes[i].color;
          ctx.beginPath();
          ctx.arc(px, py, 3 * scale, 0, TAU);
          ctx.fill();
        }
      }

      // === CENTER: Golden Identity ===
      const centerGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, 50 * scale);
      centerGrad.addColorStop(0, 'rgba(255, 215, 0, 0.3)');
      centerGrad.addColorStop(1, 'transparent');
      ctx.fillStyle = centerGrad;
      ctx.beginPath();
      ctx.arc(cx, cy, 50 * scale, 0, TAU);
      ctx.fill();

      ctx.fillStyle = '#ffd700';
      ctx.font = `bold ${16 * scale}px monospace`;
      ctx.textAlign = 'center';
      ctx.fillText('φ² + 1/φ²', cx, cy - 5 * scale);
      ctx.fillText('= 3', cx, cy + 15 * scale);

      // === OUTER RING: Network Nodes ===
      const outerRadius = coreRadius + 100 * scale;
      const nodeCount = 12;
      for (let i = 0; i < nodeCount; i++) {
        const angle = (i * TAU / nodeCount) + t * 0.1;
        const wobble = Math.sin(t * 2 + i) * 10 * scale;
        const x = cx + (outerRadius + wobble) * Math.cos(angle);
        const y = cy + (outerRadius + wobble) * Math.sin(angle);

        ctx.fillStyle = ['#0ff', '#f0f', '#ff0'][i % 3];
        ctx.beginPath();
        ctx.arc(x, y, 6 * scale, 0, TAU);
        ctx.fill();

        // Connection lines to center
        if (i % 2 === 0) {
          ctx.strokeStyle = 'rgba(0, 229, 153, 0.1)';
          ctx.beginPath();
          ctx.moveTo(x, y);
          ctx.lineTo(cx, cy);
          ctx.stroke();
        }
      }

      // === LEFT SIDE: Protocol Stack (moved down to avoid logo) ===
      const boxW = 140 * scale;
      const boxH = 110 * scale;
      const boxX = 20 * scale;
      const boxY = h / 2 - boxH - 20 * scale; // Upper middle left

      ctx.fillStyle = 'rgba(0, 255, 255, 0.1)';
      ctx.fillRect(boxX, boxY, boxW, boxH);
      ctx.strokeStyle = '#0ff';
      ctx.lineWidth = 1;
      ctx.strokeRect(boxX, boxY, boxW, boxH);

      ctx.fillStyle = '#0ff';
      ctx.font = `bold ${10 * scale}px monospace`;
      ctx.textAlign = 'center';
      ctx.fillText('PROTOCOL STACK', boxX + boxW / 2, boxY + 14 * scale);

      const layers = ['Application', 'Transport', 'Network', 'Link', 'Physical'];
      const layerColors = ['#f0f', '#ff0', '#0f0', '#0ff', '#8a2be2'];
      layers.forEach((layer, i) => {
        const ly = boxY + 22 * scale + i * 16 * scale;
        ctx.fillStyle = layerColors[i] + '40';
        ctx.fillRect(boxX + 8 * scale, ly, boxW - 16 * scale, 13 * scale);
        ctx.fillStyle = '#fff';
        ctx.font = `${9 * scale}px monospace`;
        ctx.fillText(layer, boxX + boxW / 2, ly + 10 * scale);
      });

      // === LEFT SIDE: Sacred Constants (below Protocol Stack) ===
      const sacredY = h / 2 + 20 * scale;
      ctx.fillStyle = 'rgba(255, 215, 0, 0.1)';
      ctx.fillRect(boxX, sacredY, boxW, 70 * scale);
      ctx.strokeStyle = '#ffd700';
      ctx.strokeRect(boxX, sacredY, boxW, 70 * scale);

      ctx.fillStyle = '#ffd700';
      ctx.font = `bold ${10 * scale}px monospace`;
      ctx.textAlign = 'center';
      ctx.fillText('SACRED CONSTANTS', boxX + boxW / 2, sacredY + 14 * scale);

      ctx.font = `${9 * scale}px monospace`;
      ctx.textAlign = 'left';
      ctx.fillText('φ = 1.618033...', boxX + 8 * scale, sacredY + 30 * scale);
      ctx.fillText('π × φ × e = 13.82', boxX + 8 * scale, sacredY + 44 * scale);
      ctx.fillText('L(10) = 123', boxX + 8 * scale, sacredY + 58 * scale);

      // === RIGHT SIDE: SSOT Invariants (moved down to avoid menu button) ===
      const invX = w - boxW - 20 * scale;
      const invY = h / 2 - 60 * scale; // Upper middle right
      ctx.fillStyle = 'rgba(0, 255, 255, 0.1)';
      ctx.fillRect(invX, invY, boxW, 70 * scale);
      ctx.strokeStyle = '#0ff';
      ctx.strokeRect(invX, invY, boxW, 70 * scale);

      ctx.fillStyle = '#0ff';
      ctx.font = `bold ${10 * scale}px monospace`;
      ctx.textAlign = 'center';
      ctx.fillText('SSOT INVARIANTS', invX + boxW / 2, invY + 14 * scale);

      const invariants = [
        { name: 'φ² + 1/φ² = 3', ok: true },
        { name: 'PHOENIX = 999', ok: true },
        { name: 'Ternary Logic', ok: true }
      ];
      invariants.forEach((inv, i) => {
        ctx.fillStyle = inv.ok ? '#0f0' : '#f00';
        ctx.font = `${9 * scale}px monospace`;
        ctx.textAlign = 'left';
        ctx.fillText((inv.ok ? '✓ ' : '✗ ') + inv.name, invX + 8 * scale, invY + 30 * scale + i * 14 * scale);
      });

      // === RIGHT SIDE: QKD Exchange (below SSOT) ===
      const qkdY = h / 2 + 20 * scale;
      ctx.fillStyle = 'rgba(0, 255, 0, 0.1)';
      ctx.fillRect(invX, qkdY, boxW, 70 * scale);
      ctx.strokeStyle = '#0f0';
      ctx.strokeRect(invX, qkdY, boxW, 70 * scale);

      ctx.fillStyle = '#0f0';
      ctx.font = `bold ${10 * scale}px monospace`;
      ctx.textAlign = 'center';
      ctx.fillText('QKD EXCHANGE', invX + boxW / 2, qkdY + 14 * scale);

      // Animated key bits
      const keyBits = '10110010';
      for (let i = 0; i < 8; i++) {
        const bit = keyBits[(i + Math.floor(t * 5)) % 8];
        ctx.fillStyle = bit === '1' ? '#0f0' : '#f00';
        ctx.font = `${11 * scale}px monospace`;
        ctx.fillText(bit, invX + 12 * scale + i * 15 * scale, qkdY + 35 * scale);
      }

      ctx.fillStyle = '#fff';
      ctx.font = `${8 * scale}px monospace`;
      ctx.textAlign = 'center';
      ctx.fillText('Dilithium + Kyber', invX + boxW / 2, qkdY + 55 * scale);
    }

    let lastTime = performance.now();

    const animate = (currentTime: number) => {
      const dt = Math.min((currentTime - lastTime) / 1000, 0.1);
      lastTime = currentTime;
      timeRef.current += dt;

      const w = canvas.width;
      const h = canvas.height;
      const cx = w / 2;
      const cy = h / 2;
      const t = timeRef.current;

      // Trail effect
      ctx.fillStyle = 'rgba(0, 0, 0, 0.08)';
      ctx.fillRect(0, 0, w, h);

      // TRINITY Computer mode - special rendering
      if (mode === 'trinity-computer') {
        drawTrinityComputer(ctx, w, h, t);
        animationRef.current = requestAnimationFrame(animate);
        return;
      }

      // Mode-specific background effects
      drawBackgroundEffect(ctx, mode, w, h, cx, cy, t);

      // Update and draw particles
      particlesRef.current.forEach((p, i) => {
        // Physics based on mode
        applyPhysics(p, i, mode, cx, cy, w, h, t, dt, particlesRef.current);

        // Mouse interaction - works on hover, stronger on click
        if (interactive && mouseRef.current.active) {
          const dx = mouseRef.current.x - p.x;
          const dy = mouseRef.current.y - p.y;
          const d = Math.sqrt(dx * dx + dy * dy) + 1;
          if (d < 200) {
            const force = 100 / d;
            p.vx += dx / d * force * dt;
            p.vy += dy / d * force * dt;
          }
        }

        // Physics
        p.vx *= 0.98;
        p.vy *= 0.98;
        p.x += p.vx;
        p.y += p.vy;
        p.phase += dt * PHI * p.spin;
        p.life -= dt * 0.1;

        // Reset particles
        if (p.life < 0.1 || p.x < -50 || p.x > w + 50 || p.y < -50 || p.y > h + 50) {
          resetParticle(p, mode, w, h, cx, cy);
        }

        // Boundaries
        if (p.x < 0) { p.x = 0; p.vx *= -0.5; }
        if (p.x > w) { p.x = w; p.vx *= -0.5; }
        if (p.y < 0) { p.y = 0; p.vy *= -0.5; }
        if (p.y > h) { p.y = h; p.vy *= -0.5; }

        // Draw particle
        drawParticle(ctx, p, i, mode, particlesRef.current);
      });

      // Center glow
      const gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, 200);
      gradient.addColorStop(0, `hsla(${getHueForMode(mode)}, 100%, 50%, 0.1)`);
      gradient.addColorStop(1, 'transparent');
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, w, h);

      animationRef.current = requestAnimationFrame(animate);
    };

    function drawBackgroundEffect(ctx: CanvasRenderingContext2D, mode: VizMode, w: number, h: number, cx: number, cy: number, t: number) {
      if (mode === 'wave-interference') {
        // Interference pattern
        for (let y = 0; y < h; y += 8) {
          for (let x = 0; x < w; x += 8) {
            const d1 = Math.sqrt((x - cx + 100) ** 2 + (y - cy) ** 2);
            const d2 = Math.sqrt((x - cx - 100) ** 2 + (y - cy) ** 2);
            const wave = Math.sin(d1 * 0.03 - t * 2) + Math.sin(d2 * 0.03 - t * 2);
            const intensity = (wave + 2) * 15;
            ctx.fillStyle = `rgba(0, ${intensity * 3}, ${intensity * 2}, 0.3)`;
            ctx.fillRect(x, y, 6, 6);
          }
        }
      } else if (mode === 'trinity' || mode === 'consciousness') {
        // Sacred geometry
        ctx.strokeStyle = `hsla(${getHueForMode(mode)}, 100%, 50%, 0.1)`;
        ctx.lineWidth = 1;
        for (let i = 0; i < 3; i++) {
          const angle = (i * TAU / 3) + t * 0.1;
          const r = 150 + Math.sin(t + i) * 30;
          ctx.beginPath();
          ctx.arc(cx + Math.cos(angle) * r, cy + Math.sin(angle) * r, 50, 0, TAU);
          ctx.stroke();
        }
      } else if (mode === 'multiverse') {
        // Multiple centers
        for (let i = 0; i < 5; i++) {
          const angle = (i * TAU / 5) + t * 0.2;
          const r = 200;
          const px = cx + Math.cos(angle) * r;
          const py = cy + Math.sin(angle) * r;
          const grad = ctx.createRadialGradient(px, py, 0, px, py, 100);
          grad.addColorStop(0, `hsla(${i * 72}, 100%, 50%, 0.1)`);
          grad.addColorStop(1, 'transparent');
          ctx.fillStyle = grad;
          ctx.fillRect(0, 0, w, h);
        }
      } else if (mode === 'zhar-ptitsa') {
        // Fire effect
        for (let i = 0; i < 20; i++) {
          const x = cx + Math.sin(t * 2 + i) * 100;
          const y = cy - i * 10 - Math.abs(Math.sin(t * 3 + i)) * 50;
          const grad = ctx.createRadialGradient(x, y, 0, x, y, 30 + i * 2);
          grad.addColorStop(0, `hsla(${40 - i * 2}, 100%, 60%, 0.2)`);
          grad.addColorStop(1, 'transparent');
          ctx.fillStyle = grad;
          ctx.fillRect(0, 0, w, h);
        }
      }
    }

    function applyPhysics(p: Particle, i: number, mode: VizMode, cx: number, cy: number, w: number, _h: number, t: number, dt: number, particles: Particle[]) {
      const dx = cx - p.x;
      const dy = cy - p.y;
      const d = Math.sqrt(dx * dx + dy * dy) + 1;
      void _h; // Used in some modes

      switch (mode) {
        case 'quantum-field':
        case 'quantum-life':
        case 'quantum-biology':
          p.vx += Math.sin(p.x * 0.01 + t * PHI) * 0.5 * dt * 10;
          p.vy += Math.cos(p.y * 0.01 + t) * 0.5 * dt * 10;
          break;

        case 'neural-network':
        case 'neuromorphic':
        case 'llm-architecture':
          const targetX = cx + (p.layer - 2) * (w / 6);
          p.vx += (targetX - p.x) * 0.002;
          p.vy += Math.sin(t + i * 0.1) * 0.5;
          break;

        case 'wave-interference':
        case 'qec':
          const angle = Math.atan2(dy, dx);
          p.vx = Math.cos(angle + 0.02 * p.spin) * d * 0.005;
          p.vy = Math.sin(angle + 0.02 * p.spin) * d * 0.005;
          break;

        case 'entanglement':
        case 'quantum-agents':
          if (p.entangledWith !== null && particles[p.entangledWith]) {
            const pair = particles[p.entangledWith];
            const pdx = pair.x - p.x;
            const pdy = pair.y - p.y;
            const pd = Math.sqrt(pdx * pdx + pdy * pdy) + 1;
            p.vx += pdx / pd * 0.3 * dt * 5;
            p.vy += pdy / pd * 0.3 * dt * 5;
            p.spin = -pair.spin;
          }
          p.vx += (Math.random() - 0.5) * dt * 3;
          p.vy += (Math.random() - 0.5) * dt * 3;
          break;

        case 'vortex':
        case 'multiverse':
          p.vx += (-dy / d * 3 + dx / d * 0.2) * dt;
          p.vy += (dx / d * 3 + dy / d * 0.2) * dt;
          break;

        case 'photon-beam':
        case 'zhar-ptitsa':
          const beamAngle = Math.atan2(p.y - cy, p.x - cx);
          p.vx = Math.cos(beamAngle) * 3;
          p.vy = Math.sin(beamAngle) * 3 - (mode === 'zhar-ptitsa' ? 1 : 0);
          break;

        case 'consciousness':
        case 'transcendence':
        case 'beings':
          p.vx += dx / d * 0.5 * Math.sin(t + p.phase);
          p.vy += dy / d * 0.5 * Math.cos(t + p.phase);
          p.vx += Math.sin(t * 2 + i) * 0.3;
          p.vy += Math.cos(t * 2 + i) * 0.3;
          break;

        case 'trinity':
          const triAngle = (Math.floor(i % 3) * TAU / 3) + t * 0.3;
          const triR = 150 + Math.sin(t + i * 0.1) * 50;
          const triX = cx + Math.cos(triAngle) * triR;
          const triY = cy + Math.sin(triAngle) * triR;
          p.vx += (triX - p.x) * 0.01;
          p.vy += (triY - p.y) * 0.01;
          break;

        case 'encryption':
        case 'secure':
        case 'obfuscation':
          p.vx += (Math.random() - 0.5) * 2;
          p.vy += (Math.random() - 0.5) * 2;
          if (d < 200) {
            p.vx += dx / d * 0.5;
            p.vy += dy / d * 0.5;
          }
          break;

        case 'supremacy':
          p.vx += Math.sin(p.x * 0.02 + t * 3) * dt * 15;
          p.vy += Math.cos(p.y * 0.02 + t * 3) * dt * 15;
          break;

        case 'tsp':
        case 'pas':
          // Connect to nearest neighbors
          const nearest = particles.slice(0, 20).reduce((best, other, j) => {
            if (j === i) return best;
            const od = Math.sqrt((other.x - p.x) ** 2 + (other.y - p.y) ** 2);
            return od < best.d ? { p: other, d: od } : best;
          }, { p: null as Particle | null, d: Infinity });
          if (nearest.p && nearest.d < 150) {
            p.vx += (nearest.p.x - p.x) * 0.001;
            p.vy += (nearest.p.y - p.y) * 0.001;
          }
          break;

        case 'spintronic':
          p.vx += p.spin * dy / d * 2 * dt;
          p.vy += -p.spin * dx / d * 2 * dt;
          break;

        case 'living':
          p.vx += Math.sin(t + p.phase) * 0.5;
          p.vy += Math.cos(t + p.phase) * 0.5;
          p.vx += (cx - p.x) * 0.0005;
          p.vy += (cy - p.y) * 0.0005;
          break;

        case 'matryoshka':
          const layerR = 50 + p.layer * 40;
          const layerAngle = t * (0.5 - p.layer * 0.1) + (i / particleCount) * TAU;
          const targetMX = cx + Math.cos(layerAngle) * layerR;
          const targetMY = cy + Math.sin(layerAngle) * layerR;
          p.vx += (targetMX - p.x) * 0.02;
          p.vy += (targetMY - p.y) * 0.02;
          break;

        case 'bogatyri':
          const groupAngle = (p.type * TAU / 3) + t * 0.2;
          const groupR = 180;
          const groupX = cx + Math.cos(groupAngle) * groupR;
          const groupY = cy + Math.sin(groupAngle) * groupR;
          p.vx += (groupX - p.x) * 0.01;
          p.vy += (groupY - p.y) * 0.01;
          break;

        case 'cinema4d':
          const gridX = Math.floor(p.x / 50) * 50 + 25;
          const gridY = Math.floor(p.y / 50) * 50 + 25;
          p.vx += (gridX - p.x) * 0.05 + Math.sin(t + gridX * 0.1) * 0.5;
          p.vy += (gridY - p.y) * 0.05 + Math.cos(t + gridY * 0.1) * 0.5;
          break;

        default:
          p.vx += (Math.random() - 0.5) * dt * 5;
          p.vy += (Math.random() - 0.5) * dt * 5;
      }
    }

    function resetParticle(p: Particle, mode: VizMode, w: number, h: number, cx: number, cy: number) {
      if (mode === 'photon-beam' || mode === 'zhar-ptitsa') {
        p.x = cx + (Math.random() - 0.5) * 20;
        p.y = cy + (Math.random() - 0.5) * 20;
      } else {
        p.x = Math.random() * w;
        p.y = Math.random() * h;
      }
      p.vx = (Math.random() - 0.5) * 2;
      p.vy = (Math.random() - 0.5) * 2;
      p.life = 1;
      p.amplitude = 0.3 + Math.random() * 0.7;
    }

    function drawParticle(ctx: CanvasRenderingContext2D, p: Particle, i: number, mode: VizMode, particles: Particle[]) {
      const alpha = p.amplitude * p.life * (0.4 + Math.sin(p.phase) * 0.2);
      let hue = p.hue;

      if (mode === 'entanglement' && p.entangledWith !== null) {
        hue = p.spin > 0 ? 0 : 200;
      } else if (mode === 'trinity') {
        hue = [160, 40, 280][p.type];
      } else if (mode === 'bogatyri') {
        hue = [0, 120, 240][p.type];
      }

      ctx.fillStyle = `hsla(${hue}, 100%, 60%, ${alpha})`;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size + p.amplitude * 2, 0, TAU);
      ctx.fill();

      // Draw connections
      if ((mode === 'entanglement' || mode === 'quantum-agents') && p.entangledWith !== null && i < particles.length / 2) {
        const pair = particles[p.entangledWith];
        if (pair) {
          const d = Math.sqrt((pair.x - p.x) ** 2 + (pair.y - p.y) ** 2);
          if (d < 400) {
            ctx.strokeStyle = `hsla(280, 100%, 60%, ${0.15 * (1 - d / 400) * p.life})`;
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(pair.x, pair.y);
            ctx.stroke();
          }
        }
      }

      if ((mode === 'neural-network' || mode === 'neuromorphic' || mode === 'llm-architecture') && i < 100) {
        particles.slice(0, 100).forEach((other, j) => {
          if (j <= i || other.layer !== p.layer + 1) return;
          const d = Math.sqrt((other.x - p.x) ** 2 + (other.y - p.y) ** 2);
          if (d < 200) {
            ctx.strokeStyle = `hsla(${p.hue}, 100%, 60%, ${0.1 * (1 - d / 200) * p.life})`;
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(other.x, other.y);
            ctx.stroke();
          }
        });
      }

      if ((mode === 'tsp' || mode === 'pas') && i < 30) {
        particles.slice(0, 30).forEach((other, j) => {
          if (j <= i) return;
          const d = Math.sqrt((other.x - p.x) ** 2 + (other.y - p.y) ** 2);
          if (d < 150) {
            ctx.strokeStyle = `hsla(${p.hue}, 100%, 60%, ${0.2 * (1 - d / 150)})`;
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(other.x, other.y);
            ctx.stroke();
          }
        });
      }
    }

    animationRef.current = requestAnimationFrame(animate);

    // Event handlers - mouse interaction on move
    const handleMouseMove = (e: MouseEvent) => {
      mouseRef.current.x = e.clientX;
      mouseRef.current.y = e.clientY;
      mouseRef.current.active = true;
    };
    const handleMouseLeave = () => {
      mouseRef.current.active = false;
    };
    const handleTouch = (e: TouchEvent) => {
      e.preventDefault();
      mouseRef.current.x = e.touches[0]?.clientX || mouseRef.current.x;
      mouseRef.current.y = e.touches[0]?.clientY || mouseRef.current.y;
      mouseRef.current.active = true;
    };
    const handleTouchEnd = () => {
      mouseRef.current.active = false;
    };

    if (interactive) {
      canvas.addEventListener('mousemove', handleMouseMove);
      canvas.addEventListener('mouseleave', handleMouseLeave);
      canvas.addEventListener('touchstart', handleTouch, { passive: false });
      canvas.addEventListener('touchmove', handleTouch, { passive: false });
      canvas.addEventListener('touchend', handleTouchEnd);
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
        position: 'absolute',
        top: 0,
        left: 0,
        width: '100%', 
        height: '100%', 
        display: 'block',
        cursor: interactive ? 'crosshair' : 'default'
      }} 
    />
  );
}
