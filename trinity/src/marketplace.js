/**
 * TRINITY Plugin Marketplace v23.φ
 * Discover, install, and manage plugins
 * 
 * φ² + 1/φ² = 3
 */

const PHI = 1.618033988749895;

/**
 * Plugin registry entry
 */
export class PluginEntry {
  constructor(manifest) {
    this.id = manifest.id;
    this.name = manifest.name;
    this.version = manifest.version;
    this.description = manifest.description || '';
    this.author = manifest.author || 'Unknown';
    this.repository = manifest.repository || null;
    this.homepage = manifest.homepage || null;
    this.license = manifest.license || 'MIT';
    this.tags = manifest.tags || [];
    this.downloads = manifest.downloads || 0;
    this.rating = manifest.rating || 0;
    this.verified = manifest.verified || false;
    this.createdAt = manifest.createdAt || Date.now();
    this.updatedAt = manifest.updatedAt || Date.now();
  }
}

/**
 * Plugin Marketplace
 * Central registry for TRINITY plugins
 */
export class PluginMarketplace {
  constructor() {
    this.registry = new Map();
    this.installed = new Map();
    this.storageKey = 'trinity-marketplace';
    
    // Built-in plugins
    this.registerBuiltins();
    
    // Load installed plugins
    this.loadInstalled();
  }
  
  /**
   * Register built-in plugins
   */
  registerBuiltins() {
    const builtins = [
      {
        id: 'fps-counter',
        name: 'FPS Counter',
        version: '1.0.0',
        description: 'Displays current frames per second',
        author: 'TRINITY',
        tags: ['performance', 'debug'],
        verified: true
      },
      {
        id: 'golden-grid',
        name: 'Golden Grid Overlay',
        version: '1.0.0',
        description: 'Shows φ-based grid overlay for design alignment',
        author: 'TRINITY',
        tags: ['design', 'debug'],
        verified: true
      },
      {
        id: 'section-timer',
        name: 'Section Timer',
        version: '1.0.0',
        description: 'Tracks time spent on each section',
        author: 'TRINITY',
        tags: ['analytics', 'ml'],
        verified: true
      },
      {
        id: 'cursor-trail',
        name: 'Cursor Trail',
        version: '1.0.0',
        description: 'Adds φ-spiral cursor trail effect',
        author: 'TRINITY',
        tags: ['visual', 'effects'],
        verified: true
      },
      {
        id: 'dark-mode-toggle',
        name: 'Dark Mode Toggle',
        version: '1.0.0',
        description: 'Quick toggle between dark and light themes',
        author: 'TRINITY',
        tags: ['ui', 'accessibility'],
        verified: true
      },
      {
        id: 'scroll-progress',
        name: 'Scroll Progress',
        version: '1.0.0',
        description: 'Shows reading progress indicator',
        author: 'TRINITY',
        tags: ['ui', 'navigation'],
        verified: true
      },
      {
        id: 'keyboard-shortcuts',
        name: 'Keyboard Shortcuts',
        version: '1.0.0',
        description: 'Extended keyboard navigation',
        author: 'TRINITY',
        tags: ['accessibility', 'navigation'],
        verified: true
      },
      {
        id: 'export-pdf',
        name: 'Export to PDF',
        version: '1.0.0',
        description: 'Export article as PDF document',
        author: 'TRINITY',
        tags: ['export', 'document'],
        verified: true
      }
    ];
    
    builtins.forEach(manifest => {
      this.registry.set(manifest.id, new PluginEntry(manifest));
    });
  }
  
  /**
   * Search plugins
   */
  search(query, options = {}) {
    const {
      tags = [],
      verified = null,
      sortBy = 'downloads',
      limit = 20
    } = options;
    
    let results = Array.from(this.registry.values());
    
    // Filter by query
    if (query) {
      const q = query.toLowerCase();
      results = results.filter(p => 
        p.name.toLowerCase().includes(q) ||
        p.description.toLowerCase().includes(q) ||
        p.tags.some(t => t.toLowerCase().includes(q))
      );
    }
    
    // Filter by tags
    if (tags.length > 0) {
      results = results.filter(p => 
        tags.some(t => p.tags.includes(t))
      );
    }
    
    // Filter by verified
    if (verified !== null) {
      results = results.filter(p => p.verified === verified);
    }
    
    // Sort
    results.sort((a, b) => {
      switch (sortBy) {
        case 'downloads':
          return b.downloads - a.downloads;
        case 'rating':
          return b.rating - a.rating;
        case 'name':
          return a.name.localeCompare(b.name);
        case 'updated':
          return b.updatedAt - a.updatedAt;
        default:
          return 0;
      }
    });
    
    // Limit
    return results.slice(0, limit);
  }
  
  /**
   * Get plugin by ID
   */
  get(pluginId) {
    return this.registry.get(pluginId);
  }
  
  /**
   * Install plugin
   */
  async install(pluginId) {
    const entry = this.registry.get(pluginId);
    if (!entry) {
      throw new Error(`Plugin not found: ${pluginId}`);
    }
    
    if (this.installed.has(pluginId)) {
      throw new Error(`Plugin already installed: ${pluginId}`);
    }
    
    // Load plugin code (in real implementation, fetch from CDN)
    const plugin = await this.loadPluginCode(entry);
    
    this.installed.set(pluginId, {
      entry,
      plugin,
      installedAt: Date.now(),
      enabled: true
    });
    
    // Update download count
    entry.downloads++;
    
    this.saveInstalled();
    
    return plugin;
  }
  
  /**
   * Uninstall plugin
   */
  uninstall(pluginId) {
    if (!this.installed.has(pluginId)) {
      throw new Error(`Plugin not installed: ${pluginId}`);
    }
    
    this.installed.delete(pluginId);
    this.saveInstalled();
  }
  
  /**
   * Enable/disable plugin
   */
  setEnabled(pluginId, enabled) {
    const installed = this.installed.get(pluginId);
    if (!installed) {
      throw new Error(`Plugin not installed: ${pluginId}`);
    }
    
    installed.enabled = enabled;
    this.saveInstalled();
  }
  
  /**
   * Load plugin code
   */
  async loadPluginCode(entry) {
    // Built-in plugin implementations
    const implementations = {
      'fps-counter': {
        frameCount: 0,
        lastTime: 0,
        fps: 0,
        
        init() {
          console.log('FPS Counter initialized');
        },
        
        render(ctx, state) {
          const now = performance.now();
          this.frameCount++;
          
          if (now - this.lastTime >= 1000) {
            this.fps = this.frameCount;
            this.frameCount = 0;
            this.lastTime = now;
          }
          
          ctx.fillStyle = 'rgba(0,255,136,0.9)';
          ctx.font = 'bold 14px monospace';
          ctx.textAlign = 'left';
          ctx.fillText(`${this.fps} FPS`, 10, 30);
        }
      },
      
      'golden-grid': {
        init() {},
        
        render(ctx, state) {
          const W = ctx.canvas.width;
          const H = ctx.canvas.height;
          
          ctx.strokeStyle = 'rgba(255,215,0,0.2)';
          ctx.lineWidth = 1;
          
          // Vertical φ lines
          const vLines = [W * 0.382, W * 0.5, W * 0.618];
          vLines.forEach(x => {
            ctx.beginPath();
            ctx.moveTo(x, 0);
            ctx.lineTo(x, H);
            ctx.stroke();
          });
          
          // Horizontal φ lines
          const hLines = [H * 0.382, H * 0.5, H * 0.618];
          hLines.forEach(y => {
            ctx.beginPath();
            ctx.moveTo(0, y);
            ctx.lineTo(W, y);
            ctx.stroke();
          });
        }
      },
      
      'scroll-progress': {
        init() {},
        
        render(ctx, state) {
          if (!state.scrollY || !state.maxScroll) return;
          
          const W = ctx.canvas.width;
          const progress = state.scrollY / state.maxScroll;
          
          ctx.fillStyle = 'rgba(255,215,0,0.8)';
          ctx.fillRect(0, 0, W * progress, 3);
        }
      },
      
      'cursor-trail': {
        trail: [],
        maxLength: 20,
        
        init() {
          document.addEventListener('mousemove', (e) => {
            this.trail.push({ x: e.clientX, y: e.clientY, time: Date.now() });
            if (this.trail.length > this.maxLength) {
              this.trail.shift();
            }
          });
        },
        
        render(ctx, state) {
          if (this.trail.length < 2) return;
          
          ctx.strokeStyle = 'rgba(255,215,0,0.5)';
          ctx.lineWidth = 2;
          ctx.beginPath();
          
          this.trail.forEach((point, i) => {
            const alpha = i / this.trail.length;
            ctx.globalAlpha = alpha;
            
            if (i === 0) {
              ctx.moveTo(point.x, point.y);
            } else {
              ctx.lineTo(point.x, point.y);
            }
          });
          
          ctx.stroke();
          ctx.globalAlpha = 1;
        }
      }
    };
    
    const impl = implementations[entry.id];
    if (impl) {
      return {
        id: entry.id,
        name: entry.name,
        version: entry.version,
        ...impl
      };
    }
    
    // Default empty plugin
    return {
      id: entry.id,
      name: entry.name,
      version: entry.version,
      init() {},
      render() {}
    };
  }
  
  /**
   * Get installed plugins
   */
  getInstalled() {
    return Array.from(this.installed.values());
  }
  
  /**
   * Get enabled plugins
   */
  getEnabled() {
    return this.getInstalled().filter(p => p.enabled);
  }
  
  /**
   * Save installed plugins to localStorage
   */
  saveInstalled() {
    try {
      const data = Array.from(this.installed.entries()).map(([id, info]) => ({
        id,
        installedAt: info.installedAt,
        enabled: info.enabled
      }));
      localStorage.setItem(this.storageKey, JSON.stringify(data));
    } catch (e) {
      console.warn('Marketplace: Failed to save', e);
    }
  }
  
  /**
   * Load installed plugins from localStorage
   */
  loadInstalled() {
    try {
      const saved = localStorage.getItem(this.storageKey);
      if (saved) {
        const data = JSON.parse(saved);
        data.forEach(async (info) => {
          const entry = this.registry.get(info.id);
          if (entry) {
            const plugin = await this.loadPluginCode(entry);
            this.installed.set(info.id, {
              entry,
              plugin,
              installedAt: info.installedAt,
              enabled: info.enabled
            });
          }
        });
      }
    } catch (e) {
      console.warn('Marketplace: Failed to load', e);
    }
  }
  
  /**
   * Get marketplace stats
   */
  getStats() {
    return {
      totalPlugins: this.registry.size,
      installedCount: this.installed.size,
      enabledCount: this.getEnabled().length,
      categories: this.getCategories()
    };
  }
  
  /**
   * Get plugin categories
   */
  getCategories() {
    const categories = {};
    
    this.registry.forEach(entry => {
      entry.tags.forEach(tag => {
        categories[tag] = (categories[tag] || 0) + 1;
      });
    });
    
    return Object.entries(categories)
      .sort((a, b) => b[1] - a[1])
      .map(([name, count]) => ({ name, count }));
  }
}

// Singleton instance
export const marketplace = new PluginMarketplace();

export default marketplace;
