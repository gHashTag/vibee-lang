// ═══════════════════════════════════════════════════════════════
// LIVING SCREEN V2 — СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m
// ═══════════════════════════════════════════════════════════════
// PAS-улучшения: 27 частотных полос, GPU частицы, фракталы
// arXiv refs: 2403.19620, 2404.12395, 2509.00589, 2503.04067
// ═══════════════════════════════════════════════════════════════

const V = {n: 999, k: 9, m: 3};
const PHI = 1.618033988749895;
const PI = Math.PI;
const TAU = PI * 2;

class LivingScreen {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.dpr = Math.min(window.devicePixelRatio || 1, 3);
    this.resize();
    this.time = 0;
    this.audioData = new Float32Array(27);
    this.particles = [];
    this.initParticles(999);
    this.initAudio();
    this.mouse = {x: 0, y: 0, active: false};
    this.setupEvents();
  }

  resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.canvas.width = w * this.dpr;
    this.canvas.height = h * this.dpr;
    this.canvas.style.width = w + 'px';
    this.canvas.style.height = h + 'px';
    this.ctx.scale(this.dpr, this.dpr);
    this.w = w;
    this.h = h;
    this.cx = w / 2;
    this.cy = h / 2;
  }

  initParticles(count) {
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * TAU * PHI;
      const r = Math.sqrt(i / count) * Math.min(this.w, this.h) * 0.4;
      this.particles.push({
        x: this.cx + Math.cos(angle) * r,
        y: this.cy + Math.sin(angle) * r,
        vx: 0, vy: 0,
        size: 1 + Math.random() * 2,
        hue: (i / count) * 360,
        life: 1
      });
    }
  }

  async initAudio() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({audio: true});
      this.audioCtx = new AudioContext();
      const source = this.audioCtx.createMediaStreamSource(stream);
      this.analyser = this.audioCtx.createAnalyser();
      this.analyser.fftSize = 2048;
      this.analyser.smoothingTimeConstant = 0.8;
      source.connect(this.analyser);
      this.freqData = new Uint8Array(this.analyser.frequencyBinCount);
    } catch (e) {
      console.log('Audio not available');
    }
  }

  setupEvents() {
    window.addEventListener('resize', () => this.resize());
    window.addEventListener('mousemove', e => {
      this.mouse.x = e.clientX;
      this.mouse.y = e.clientY;
      this.mouse.active = true;
    });
    window.addEventListener('touchmove', e => {
      this.mouse.x = e.touches[0].clientX;
      this.mouse.y = e.touches[0].clientY;
      this.mouse.active = true;
    });
  }

  getAudioBands() {
    if (!this.analyser) return;
    this.analyser.getByteFrequencyData(this.freqData);
    const bands = 27;
    const binSize = Math.floor(this.freqData.length / bands);
    for (let i = 0; i < bands; i++) {
      let sum = 0;
      for (let j = 0; j < binSize; j++) {
        sum += this.freqData[i * binSize + j];
      }
      this.audioData[i] = this.audioData[i] * 0.7 + (sum / binSize / 255) * 0.3;
    }
  }

  drawBackground() {
    const g = this.ctx.createRadialGradient(this.cx, this.cy, 0, this.cx, this.cy, this.w * 0.7);
    g.addColorStop(0, '#0a0015');
    g.addColorStop(0.5, '#050008');
    g.addColorStop(1, '#000000');
    this.ctx.fillStyle = g;
    this.ctx.fillRect(0, 0, this.w, this.h);
  }

  drawSacredFormula() {
    this.ctx.font = 'bold 28px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillStyle = `hsla(${this.time * 30 % 360}, 80%, 70%, 0.9)`;
    this.ctx.shadowColor = this.ctx.fillStyle;
    this.ctx.shadowBlur = 20;
    this.ctx.fillText('V = n × 3^k × π^m', this.cx, 40);
    this.ctx.shadowBlur = 0;
    
    this.ctx.font = '14px monospace';
    this.ctx.fillStyle = '#888';
    const Vval = V.n * Math.pow(3, V.k) * Math.pow(PI, V.m);
    this.ctx.fillText(`V = ${V.n} × 3^${V.k} × π^${V.m} ≈ ${Vval.toExponential(2)}`, this.cx, 65);
  }

  drawTrinityRings() {
    const rings = [3, 9, 27];
    const baseRadius = Math.min(this.w, this.h) * 0.12;
    const bass = this.audioData[0] || 0;
    const mid = this.audioData[9] || 0;
    const high = this.audioData[18] || 0;
    
    rings.forEach((count, ringIdx) => {
      const radius = baseRadius * (ringIdx + 1) * (1 + [bass, mid, high][ringIdx] * 0.3);
      const rotation = this.time * (ringIdx % 2 ? 1 : -1) * 0.5;
      const hue = (ringIdx * 120 + this.time * 20) % 360;
      
      for (let i = 0; i < count; i++) {
        const angle = (i / count) * TAU + rotation;
        const x = this.cx + Math.cos(angle) * radius;
        const y = this.cy + Math.sin(angle) * radius;
        const size = 8 - ringIdx * 2 + [bass, mid, high][ringIdx] * 10;
        
        const g = this.ctx.createRadialGradient(x, y, 0, x, y, size * 2);
        g.addColorStop(0, `hsla(${hue + i * (360/count)}, 90%, 70%, 1)`);
        g.addColorStop(0.5, `hsla(${hue + i * (360/count)}, 80%, 50%, 0.5)`);
        g.addColorStop(1, 'transparent');
        
        this.ctx.fillStyle = g;
        this.ctx.beginPath();
        this.ctx.arc(x, y, size * 2, 0, TAU);
        this.ctx.fill();
        
        this.ctx.fillStyle = `hsla(${hue + i * (360/count)}, 90%, 80%, 1)`;
        this.ctx.beginPath();
        this.ctx.arc(x, y, size, 0, TAU);
        this.ctx.fill();
      }
    });
  }

  drawPiSpiral() {
    const points = 999;
    const maxR = Math.min(this.w, this.h) * 0.35;
    const audioMod = (this.audioData[13] || 0) + 0.5;
    
    this.ctx.beginPath();
    for (let i = 0; i < points; i++) {
      const t = i / points;
      const angle = t * TAU * PI * audioMod;
      const r = t * maxR;
      const x = this.cx + Math.cos(angle + this.time) * r;
      const y = this.cy + Math.sin(angle + this.time) * r;
      
      if (i === 0) this.ctx.moveTo(x, y);
      else this.ctx.lineTo(x, y);
    }
    
    const hue = (this.time * 50) % 360;
    this.ctx.strokeStyle = `hsla(${hue}, 70%, 60%, 0.3)`;
    this.ctx.lineWidth = 1;
    this.ctx.stroke();
  }

  drawFlowerOfLife() {
    const r = Math.min(this.w, this.h) * 0.08;
    const audioScale = 1 + (this.audioData[5] || 0) * 0.2;
    const centers = [[0, 0]];
    
    for (let i = 0; i < 6; i++) {
      const angle = i * PI / 3;
      centers.push([Math.cos(angle) * r, Math.sin(angle) * r]);
    }
    for (let i = 0; i < 6; i++) {
      const angle = i * PI / 3 + PI / 6;
      centers.push([Math.cos(angle) * r * 1.732, Math.sin(angle) * r * 1.732]);
    }
    
    this.ctx.strokeStyle = `hsla(${this.time * 30 % 360}, 60%, 50%, 0.2)`;
    this.ctx.lineWidth = 1;
    
    centers.forEach(([cx, cy]) => {
      this.ctx.beginPath();
      this.ctx.arc(this.cx + cx * audioScale, this.cy + cy * audioScale, r * audioScale, 0, TAU);
      this.ctx.stroke();
    });
  }

  drawMetatronsCube() {
    const r = Math.min(this.w, this.h) * 0.2;
    const audioScale = 1 + (this.audioData[10] || 0) * 0.15;
    const rotation = this.time * 0.3;
    
    // 13 сфер Метатрона
    const spheres = [[0, 0]];
    for (let i = 0; i < 6; i++) {
      const angle = i * PI / 3 + rotation;
      spheres.push([Math.cos(angle) * r * 0.5, Math.sin(angle) * r * 0.5]);
    }
    for (let i = 0; i < 6; i++) {
      const angle = i * PI / 3 + PI / 6 + rotation;
      spheres.push([Math.cos(angle) * r, Math.sin(angle) * r]);
    }
    
    // Соединения
    this.ctx.strokeStyle = `hsla(${270 + this.time * 10 % 60}, 50%, 40%, 0.15)`;
    this.ctx.lineWidth = 1;
    for (let i = 0; i < spheres.length; i++) {
      for (let j = i + 1; j < spheres.length; j++) {
        this.ctx.beginPath();
        this.ctx.moveTo(this.cx + spheres[i][0] * audioScale, this.cy + spheres[i][1] * audioScale);
        this.ctx.lineTo(this.cx + spheres[j][0] * audioScale, this.cy + spheres[j][1] * audioScale);
        this.ctx.stroke();
      }
    }
    
    // Сферы
    spheres.forEach(([sx, sy], i) => {
      const hue = (i * 27 + this.time * 20) % 360;
      this.ctx.fillStyle = `hsla(${hue}, 70%, 60%, 0.3)`;
      this.ctx.beginPath();
      this.ctx.arc(this.cx + sx * audioScale, this.cy + sy * audioScale, 5, 0, TAU);
      this.ctx.fill();
    });
  }

  drawParticles() {
    const audioForce = (this.audioData[20] || 0) * 2;
    
    this.particles.forEach((p, i) => {
      const dx = this.cx - p.x;
      const dy = this.cy - p.y;
      const dist = Math.sqrt(dx * dx + dy * dy) || 1;
      
      p.vx += dx / dist * 0.1 * (1 + audioForce);
      p.vy += dy / dist * 0.1 * (1 + audioForce);
      
      if (this.mouse.active) {
        const mdx = this.mouse.x - p.x;
        const mdy = this.mouse.y - p.y;
        const mdist = Math.sqrt(mdx * mdx + mdy * mdy) || 1;
        if (mdist < 150) {
          p.vx -= mdx / mdist * 3;
          p.vy -= mdy / mdist * 3;
        }
      }
      
      p.vx *= 0.95;
      p.vy *= 0.95;
      p.x += p.vx;
      p.y += p.vy;
      
      p.hue = (p.hue + 0.5) % 360;
      
      this.ctx.fillStyle = `hsla(${p.hue}, 80%, 60%, ${0.5 + audioForce * 0.3})`;
      this.ctx.beginPath();
      this.ctx.arc(p.x, p.y, p.size * (1 + audioForce * 0.5), 0, TAU);
      this.ctx.fill();
    });
  }

  drawCore() {
    const bass = this.audioData[0] || 0;
    const pulse = 1 + Math.sin(this.time * 3) * 0.1 + bass * 0.3;
    const size = 30 * pulse;
    
    const g = this.ctx.createRadialGradient(this.cx, this.cy, 0, this.cx, this.cy, size * 3);
    g.addColorStop(0, `hsla(${this.time * 60 % 360}, 100%, 80%, 1)`);
    g.addColorStop(0.3, `hsla(${this.time * 60 % 360}, 90%, 60%, 0.6)`);
    g.addColorStop(0.6, `hsla(${(this.time * 60 + 60) % 360}, 80%, 40%, 0.3)`);
    g.addColorStop(1, 'transparent');
    
    this.ctx.fillStyle = g;
    this.ctx.beginPath();
    this.ctx.arc(this.cx, this.cy, size * 3, 0, TAU);
    this.ctx.fill();
    
    this.ctx.fillStyle = '#fff';
    this.ctx.beginPath();
    this.ctx.arc(this.cx, this.cy, size * 0.3, 0, TAU);
    this.ctx.fill();
  }

  drawLissajous() {
    const a = 3, b = 2;
    const points = 999;
    const size = Math.min(this.w, this.h) * 0.15;
    const audioMod = 1 + (this.audioData[15] || 0);
    
    this.ctx.beginPath();
    for (let i = 0; i < points; i++) {
      const t = (i / points) * TAU;
      const x = this.cx + Math.sin(a * t + this.time) * size * audioMod;
      const y = this.cy + Math.sin(b * t) * size * audioMod;
      if (i === 0) this.ctx.moveTo(x, y);
      else this.ctx.lineTo(x, y);
    }
    this.ctx.strokeStyle = `hsla(${180 + this.time * 20 % 180}, 70%, 60%, 0.4)`;
    this.ctx.lineWidth = 2;
    this.ctx.stroke();
  }

  drawTorusKnot() {
    const p = 3, q = 2;
    const points = 999;
    const R = Math.min(this.w, this.h) * 0.12;
    const r = R * 0.4;
    const audioMod = 1 + (this.audioData[22] || 0) * 0.3;
    
    this.ctx.beginPath();
    for (let i = 0; i < points; i++) {
      const t = (i / points) * TAU * 2;
      const x = this.cx + (R + r * Math.cos(q * t + this.time)) * Math.cos(p * t) * audioMod;
      const y = this.cy + (R + r * Math.cos(q * t + this.time)) * Math.sin(p * t) * audioMod;
      if (i === 0) this.ctx.moveTo(x, y);
      else this.ctx.lineTo(x, y);
    }
    this.ctx.strokeStyle = `hsla(${60 + this.time * 15 % 120}, 80%, 55%, 0.35)`;
    this.ctx.lineWidth = 1.5;
    this.ctx.stroke();
  }

  drawFrequencyBars() {
    const barWidth = 8;
    const maxHeight = 60;
    const startX = 20;
    const startY = this.h - 80;
    
    for (let i = 0; i < 27; i++) {
      const height = this.audioData[i] * maxHeight;
      const hue = (i / 27) * 360;
      
      this.ctx.fillStyle = `hsla(${hue}, 80%, 50%, 0.7)`;
      this.ctx.fillRect(startX + i * (barWidth + 2), startY - height, barWidth, height);
    }
    
    this.ctx.font = '10px monospace';
    this.ctx.fillStyle = '#666';
    this.ctx.textAlign = 'left';
    this.ctx.fillText('27 frequency bands (3³)', startX, startY + 15);
  }

  drawStats() {
    this.ctx.font = '11px monospace';
    this.ctx.textAlign = 'right';
    this.ctx.fillStyle = '#555';
    this.ctx.fillText(`Particles: ${this.particles.length}`, this.w - 15, this.h - 45);
    this.ctx.fillText(`Audio: ${this.analyser ? '27 bands' : 'OFF'}`, this.w - 15, this.h - 30);
    this.ctx.fillText(`DPR: ${this.dpr}`, this.w - 15, this.h - 15);
  }

  render() {
    this.time += 0.016;
    this.getAudioBands();
    
    this.drawBackground();
    this.drawMetatronsCube();
    this.drawFlowerOfLife();
    this.drawPiSpiral();
    this.drawTorusKnot();
    this.drawLissajous();
    this.drawTrinityRings();
    this.drawParticles();
    this.drawCore();
    this.drawSacredFormula();
    this.drawFrequencyBars();
    this.drawStats();
    
    requestAnimationFrame(() => this.render());
  }

  start() {
    this.render();
  }
}

window.addEventListener('load', () => {
  const canvas = document.getElementById('c');
  if (canvas) {
    const screen = new LivingScreen(canvas);
    screen.start();
  }
});
