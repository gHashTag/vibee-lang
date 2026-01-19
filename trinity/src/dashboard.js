/**
 * TRINITY Performance Dashboard v23.φ
 * Real-time performance monitoring and analytics
 * 
 * φ² + 1/φ² = 3
 */

const PHI = 1.618033988749895;

/**
 * Performance Metrics Collector
 */
export class MetricsCollector {
  constructor() {
    this.metrics = {
      fps: [],
      frameTime: [],
      memory: [],
      renderTime: [],
      layoutTime: [],
      jsHeap: []
    };
    
    this.maxSamples = 100;
    this.lastFrameTime = 0;
    this.frameCount = 0;
    this.fps = 0;
  }
  
  /**
   * Record frame
   */
  recordFrame(timestamp) {
    this.frameCount++;
    
    if (timestamp - this.lastFrameTime >= 1000) {
      this.fps = this.frameCount;
      this.frameCount = 0;
      this.lastFrameTime = timestamp;
      
      this.addMetric('fps', this.fps);
    }
  }
  
  /**
   * Record frame time
   */
  recordFrameTime(ms) {
    this.addMetric('frameTime', ms);
  }
  
  /**
   * Record render time
   */
  recordRenderTime(ms) {
    this.addMetric('renderTime', ms);
  }
  
  /**
   * Record layout time
   */
  recordLayoutTime(ms) {
    this.addMetric('layoutTime', ms);
  }
  
  /**
   * Record memory usage
   */
  recordMemory() {
    if (performance.memory) {
      this.addMetric('jsHeap', performance.memory.usedJSHeapSize / 1024 / 1024);
      this.addMetric('memory', performance.memory.totalJSHeapSize / 1024 / 1024);
    }
  }
  
  /**
   * Add metric sample
   */
  addMetric(name, value) {
    if (!this.metrics[name]) {
      this.metrics[name] = [];
    }
    
    this.metrics[name].push({
      value,
      timestamp: Date.now()
    });
    
    // Trim old samples
    if (this.metrics[name].length > this.maxSamples) {
      this.metrics[name].shift();
    }
  }
  
  /**
   * Get metric statistics
   */
  getStats(name) {
    const samples = this.metrics[name] || [];
    if (samples.length === 0) {
      return { min: 0, max: 0, avg: 0, current: 0 };
    }
    
    const values = samples.map(s => s.value);
    const sum = values.reduce((a, b) => a + b, 0);
    
    return {
      min: Math.min(...values),
      max: Math.max(...values),
      avg: sum / values.length,
      current: values[values.length - 1]
    };
  }
  
  /**
   * Get all stats
   */
  getAllStats() {
    const stats = {};
    Object.keys(this.metrics).forEach(name => {
      stats[name] = this.getStats(name);
    });
    return stats;
  }
  
  /**
   * Clear metrics
   */
  clear() {
    Object.keys(this.metrics).forEach(name => {
      this.metrics[name] = [];
    });
  }
}

/**
 * Performance Dashboard
 * Renders performance metrics overlay
 */
export class PerformanceDashboard {
  constructor() {
    this.collector = new MetricsCollector();
    this.visible = false;
    this.position = { x: 10, y: 10 };
    this.size = { width: 300, height: 400 };
    this.theme = 'dark';
  }
  
  /**
   * Toggle visibility
   */
  toggle() {
    this.visible = !this.visible;
  }
  
  /**
   * Show dashboard
   */
  show() {
    this.visible = true;
  }
  
  /**
   * Hide dashboard
   */
  hide() {
    this.visible = false;
  }
  
  /**
   * Update metrics
   */
  update(timestamp) {
    this.collector.recordFrame(timestamp);
    this.collector.recordMemory();
  }
  
  /**
   * Record render time
   */
  recordRender(startTime) {
    const elapsed = performance.now() - startTime;
    this.collector.recordRenderTime(elapsed);
  }
  
  /**
   * Render dashboard
   */
  render(ctx) {
    if (!this.visible) return;
    
    const { x, y } = this.position;
    const { width, height } = this.size;
    const stats = this.collector.getAllStats();
    const isDark = this.theme === 'dark';
    
    // Background
    ctx.fillStyle = isDark ? 'rgba(0,0,0,0.9)' : 'rgba(255,255,255,0.95)';
    ctx.beginPath();
    ctx.roundRect(x, y, width, height, 8);
    ctx.fill();
    
    // Border
    ctx.strokeStyle = 'rgba(255,215,0,0.5)';
    ctx.lineWidth = 2;
    ctx.stroke();
    
    // Title
    ctx.fillStyle = '#ffd700';
    ctx.font = 'bold 14px -apple-system, sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText('⚡ Performance Dashboard v23.φ', x + 10, y + 25);
    
    // Separator
    ctx.strokeStyle = 'rgba(255,215,0,0.3)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x + 10, y + 35);
    ctx.lineTo(x + width - 10, y + 35);
    ctx.stroke();
    
    // Metrics
    let yOffset = 55;
    const lineHeight = 28;
    
    const metrics = [
      { name: 'FPS', key: 'fps', unit: '', good: 55, bad: 30 },
      { name: 'Frame Time', key: 'frameTime', unit: 'ms', good: 16, bad: 33, invert: true },
      { name: 'Render Time', key: 'renderTime', unit: 'ms', good: 8, bad: 16, invert: true },
      { name: 'JS Heap', key: 'jsHeap', unit: 'MB', good: 50, bad: 100, invert: true },
      { name: 'Memory', key: 'memory', unit: 'MB', good: 100, bad: 200, invert: true }
    ];
    
    metrics.forEach(metric => {
      const stat = stats[metric.key] || { current: 0, avg: 0, min: 0, max: 0 };
      const value = stat.current;
      
      // Determine color
      let color;
      if (metric.invert) {
        color = value <= metric.good ? '#0f8' : value >= metric.bad ? '#f44' : '#ffd700';
      } else {
        color = value >= metric.good ? '#0f8' : value <= metric.bad ? '#f44' : '#ffd700';
      }
      
      // Label
      ctx.fillStyle = isDark ? '#888' : '#666';
      ctx.font = '12px -apple-system, sans-serif';
      ctx.fillText(metric.name, x + 10, y + yOffset);
      
      // Value
      ctx.fillStyle = color;
      ctx.font = 'bold 14px monospace';
      ctx.textAlign = 'right';
      ctx.fillText(
        `${value.toFixed(metric.unit === 'ms' ? 1 : 0)}${metric.unit}`,
        x + width - 10,
        y + yOffset
      );
      
      // Mini chart
      this.renderMiniChart(ctx, x + 100, y + yOffset - 10, 80, 16, 
        this.collector.metrics[metric.key] || [], color);
      
      ctx.textAlign = 'left';
      yOffset += lineHeight;
    });
    
    // Golden Identity
    yOffset += 10;
    ctx.strokeStyle = 'rgba(255,215,0,0.3)';
    ctx.beginPath();
    ctx.moveTo(x + 10, y + yOffset);
    ctx.lineTo(x + width - 10, y + yOffset);
    ctx.stroke();
    
    yOffset += 20;
    ctx.fillStyle = '#ffd700';
    ctx.font = '12px monospace';
    ctx.textAlign = 'center';
    ctx.fillText('φ² + 1/φ² = 3', x + width / 2, y + yOffset);
    
    // Stats summary
    yOffset += 25;
    ctx.fillStyle = isDark ? '#666' : '#888';
    ctx.font = '10px -apple-system, sans-serif';
    ctx.textAlign = 'left';
    
    const fpsStats = stats.fps || { avg: 0, min: 0, max: 0 };
    ctx.fillText(
      `FPS: avg ${fpsStats.avg.toFixed(0)} | min ${fpsStats.min.toFixed(0)} | max ${fpsStats.max.toFixed(0)}`,
      x + 10,
      y + yOffset
    );
    
    // Keyboard hint
    yOffset += 20;
    ctx.fillStyle = isDark ? '#444' : '#aaa';
    ctx.fillText('Press D to toggle dashboard', x + 10, y + yOffset);
  }
  
  /**
   * Render mini chart
   */
  renderMiniChart(ctx, x, y, width, height, samples, color) {
    if (samples.length < 2) return;
    
    const values = samples.slice(-20).map(s => s.value);
    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = max - min || 1;
    
    ctx.strokeStyle = color;
    ctx.lineWidth = 1;
    ctx.beginPath();
    
    values.forEach((value, i) => {
      const px = x + (i / (values.length - 1)) * width;
      const py = y + height - ((value - min) / range) * height;
      
      if (i === 0) {
        ctx.moveTo(px, py);
      } else {
        ctx.lineTo(px, py);
      }
    });
    
    ctx.stroke();
  }
  
  /**
   * Export metrics
   */
  exportMetrics() {
    return {
      version: 'v23.φ',
      exportedAt: Date.now(),
      stats: this.collector.getAllStats(),
      samples: this.collector.metrics
    };
  }
}

// Singleton instance
export const dashboard = new PerformanceDashboard();

// Keyboard shortcut
if (typeof window !== 'undefined') {
  window.addEventListener('keydown', (e) => {
    if (e.key === 'd' || e.key === 'D') {
      if (!e.ctrlKey && !e.metaKey) {
        dashboard.toggle();
      }
    }
  });
}

export default dashboard;
