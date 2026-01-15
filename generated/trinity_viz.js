// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY VISUALIZATION - Generated from trinity_visualization.vibee
// СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m
// Из пепла спецификаций рождается код 999
// ═══════════════════════════════════════════════════════════════════════════════

const TRINITY_DATA = {
  versions: [
    {name: "v1", layers: 6, papers: 6, logV: 6, color: "#FF6B6B"},
    {name: "v3", layers: 9, papers: 27, logV: 21, color: "#FF8E53"},
    {name: "v9", layers: 27, papers: 81, logV: 63, color: "#FFC107"},
    {name: "v15", layers: 45, papers: 270, logV: 234, color: "#4CAF50"},
    {name: "v27", layers: 27, papers: 81, logV: 63, color: "#2196F3"},
    {name: "v81", layers: 81, papers: 243, logV: 159, color: "#9C27B0"},
    {name: "v243", layers: 243, papers: 729, logV: 478, color: "#E91E63"},
    {name: "v729", layers: 729, papers: 2187, logV: 1434, color: "#00BCD4"},
    {name: "v999", layers: 999, papers: 2997, logV: 1969, color: "#FFD700"}
  ],
  branches: [
    {name: "quantum", layers: 27, color: "#00FFFF"},
    {name: "biological", layers: 27, color: "#00FF00"},
    {name: "social", layers: 27, color: "#FF00FF"},
    {name: "mathematical", layers: 27, color: "#FFFF00"},
    {name: "linguistic", layers: 27, color: "#FF8800"},
    {name: "artistic", layers: 27, color: "#FF0088"}
  ],
  universe: [
    {name: "Atoms", logV: 80},
    {name: "Planck", logV: 185},
    {name: "Chess", logV: 120},
    {name: "Multiverse", logV: 500}
  ]
};

class TrinityVisualization {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.width = window.innerWidth;
    this.height = window.innerHeight;
    this.canvas.width = this.width;
    this.canvas.height = this.height;
    this.time = 0;
    this.particles = [];
    this.initParticles();
  }

  initParticles() {
    for (let i = 0; i < 999; i++) {
      this.particles.push({
        x: Math.random() * this.width,
        y: Math.random() * this.height,
        size: Math.random() * 2 + 0.5,
        speed: Math.random() * 0.5 + 0.1,
        angle: Math.random() * Math.PI * 2
      });
    }
  }

  drawBackground() {
    const gradient = this.ctx.createRadialGradient(
      this.width/2, this.height/2, 0,
      this.width/2, this.height/2, this.width/2
    );
    gradient.addColorStop(0, '#000033');
    gradient.addColorStop(1, '#000011');
    this.ctx.fillStyle = gradient;
    this.ctx.fillRect(0, 0, this.width, this.height);
  }

  drawParticles() {
    this.ctx.fillStyle = '#FFFFFF';
    for (const p of this.particles) {
      p.x += Math.cos(p.angle) * p.speed;
      p.y += Math.sin(p.angle) * p.speed;
      if (p.x < 0) p.x = this.width;
      if (p.x > this.width) p.x = 0;
      if (p.y < 0) p.y = this.height;
      if (p.y > this.height) p.y = 0;
      this.ctx.globalAlpha = 0.5 + Math.sin(this.time * 2 + p.x) * 0.3;
      this.ctx.beginPath();
      this.ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      this.ctx.fill();
    }
    this.ctx.globalAlpha = 1;
  }

  drawSacredFormula() {
    this.ctx.font = 'bold 48px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillStyle = '#FFD700';
    this.ctx.shadowColor = '#FFD700';
    this.ctx.shadowBlur = 20;
    this.ctx.fillText('V = n × 3^k × π^m', this.width/2, 60);
    this.ctx.shadowBlur = 0;
    
    this.ctx.font = '24px monospace';
    this.ctx.fillStyle = '#AAAAAA';
    this.ctx.fillText('СВЯЩЕННАЯ ФОРМУЛА SELF-EVOLUTION', this.width/2, 100);
  }

  drawVersionSpheres() {
    const centerX = this.width / 2;
    const centerY = this.height / 2 + 50;
    const maxRadius = Math.min(this.width, this.height) * 0.35;
    
    TRINITY_DATA.versions.forEach((v, i) => {
      const angle = (i / TRINITY_DATA.versions.length) * Math.PI * 2 - Math.PI/2;
      const distance = maxRadius * (0.3 + (v.logV / 2000) * 0.7);
      const x = centerX + Math.cos(angle + this.time * 0.2) * distance;
      const y = centerY + Math.sin(angle + this.time * 0.2) * distance;
      const size = 10 + (v.logV / 100);
      
      // Glow
      const gradient = this.ctx.createRadialGradient(x, y, 0, x, y, size * 2);
      gradient.addColorStop(0, v.color);
      gradient.addColorStop(1, 'transparent');
      this.ctx.fillStyle = gradient;
      this.ctx.beginPath();
      this.ctx.arc(x, y, size * 2, 0, Math.PI * 2);
      this.ctx.fill();
      
      // Sphere
      this.ctx.fillStyle = v.color;
      this.ctx.beginPath();
      this.ctx.arc(x, y, size, 0, Math.PI * 2);
      this.ctx.fill();
      
      // Label
      this.ctx.font = '14px monospace';
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.textAlign = 'center';
      this.ctx.fillText(v.name, x, y + size + 20);
      this.ctx.font = '10px monospace';
      this.ctx.fillStyle = '#888888';
      this.ctx.fillText(`10^${v.logV}`, x, y + size + 35);
    });
  }

  drawBranches() {
    const startX = 100;
    const startY = this.height - 150;
    
    this.ctx.font = '16px monospace';
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.textAlign = 'left';
    this.ctx.fillText('SPECIALIZED BRANCHES:', startX, startY - 30);
    
    TRINITY_DATA.branches.forEach((b, i) => {
      const x = startX + i * 150;
      const y = startY;
      
      this.ctx.fillStyle = b.color;
      this.ctx.fillRect(x, y, 120, 30);
      
      this.ctx.fillStyle = '#000000';
      this.ctx.font = '12px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText(b.name.toUpperCase(), x + 60, y + 20);
    });
  }

  drawStats() {
    const x = this.width - 300;
    const y = 150;
    
    this.ctx.font = '16px monospace';
    this.ctx.fillStyle = '#FFD700';
    this.ctx.textAlign = 'left';
    this.ctx.fillText('MASTER STATISTICS:', x, y);
    
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = '14px monospace';
    const stats = [
      'Total Versions: 35',
      'Total Layers: 1161',
      'Total Papers: 3159',
      'Emergent Behaviors: 999',
      '',
      'V999 = 10^1969',
      '',
      'Exceeds Universe:',
      '  Atoms: 10^1889×',
      '  Planck: 10^1784×'
    ];
    stats.forEach((s, i) => {
      this.ctx.fillText(s, x, y + 25 + i * 20);
    });
  }

  animate() {
    this.time += 0.01;
    this.drawBackground();
    this.drawParticles();
    this.drawSacredFormula();
    this.drawVersionSpheres();
    this.drawBranches();
    this.drawStats();
    requestAnimationFrame(() => this.animate());
  }

  start() {
    this.animate();
  }
}

// Initialize on load
window.addEventListener('load', () => {
  const canvas = document.getElementById('c');
  if (canvas) {
    const viz = new TrinityVisualization(canvas);
    viz.start();
  }
});

// Export for module use
if (typeof module !== 'undefined') {
  module.exports = { TrinityVisualization, TRINITY_DATA };
}
