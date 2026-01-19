/**
 * TRINITY Plugin Architecture v21.φ
 * Extensible plugin system with φ-based lifecycle
 * 
 * φ² + 1/φ² = 3
 */

const PHI = 1.618033988749895;

/**
 * Plugin lifecycle phases
 */
export const PluginPhase = {
  REGISTERED: 'registered',
  INITIALIZING: 'initializing',
  ACTIVE: 'active',
  SUSPENDED: 'suspended',
  UNLOADING: 'unloading',
  UNLOADED: 'unloaded',
  ERROR: 'error'
};

/**
 * Plugin hook points
 */
export const PluginHooks = {
  // Lifecycle
  BEFORE_INIT: 'beforeInit',
  AFTER_INIT: 'afterInit',
  BEFORE_RENDER: 'beforeRender',
  AFTER_RENDER: 'afterRender',
  
  // Events
  ON_SCROLL: 'onScroll',
  ON_RESIZE: 'onResize',
  ON_TAB_CHANGE: 'onTabChange',
  ON_THEME_CHANGE: 'onThemeChange',
  
  // Data
  ON_DATA_LOAD: 'onDataLoad',
  ON_DATA_SAVE: 'onDataSave',
  
  // Custom
  CUSTOM: 'custom'
};

/**
 * Plugin base class
 */
export class Plugin {
  constructor(manifest) {
    this.id = manifest.id;
    this.name = manifest.name;
    this.version = manifest.version;
    this.description = manifest.description || '';
    this.author = manifest.author || 'Unknown';
    this.dependencies = manifest.dependencies || [];
    this.hooks = manifest.hooks || {};
    this.phase = PluginPhase.REGISTERED;
    this.error = null;
  }
  
  /**
   * Initialize plugin
   * Override in subclass
   */
  async init() {
    // Default implementation
  }
  
  /**
   * Cleanup plugin
   * Override in subclass
   */
  async cleanup() {
    // Default implementation
  }
  
  /**
   * Render plugin UI
   * @param {CanvasRenderingContext2D} ctx - Canvas context
   * @param {object} state - Application state
   */
  render(ctx, state) {
    // Default implementation - no rendering
  }
  
  /**
   * Handle hook
   * @param {string} hook - Hook name
   * @param {any} data - Hook data
   */
  handleHook(hook, data) {
    if (this.hooks[hook]) {
      return this.hooks[hook].call(this, data);
    }
  }
}

/**
 * Plugin Manager
 * Manages plugin lifecycle and hooks
 */
export class PluginManager {
  constructor() {
    this.plugins = new Map();
    this.hookListeners = new Map();
    this.loadOrder = [];
  }
  
  /**
   * Register a plugin
   * @param {Plugin} plugin - Plugin instance
   */
  register(plugin) {
    if (this.plugins.has(plugin.id)) {
      console.warn(`Plugin ${plugin.id} already registered`);
      return false;
    }
    
    this.plugins.set(plugin.id, plugin);
    console.log(`📦 Plugin registered: ${plugin.name} v${plugin.version}`);
    return true;
  }
  
  /**
   * Unregister a plugin
   * @param {string} pluginId - Plugin ID
   */
  async unregister(pluginId) {
    const plugin = this.plugins.get(pluginId);
    if (!plugin) return false;
    
    // Cleanup
    plugin.phase = PluginPhase.UNLOADING;
    await plugin.cleanup();
    plugin.phase = PluginPhase.UNLOADED;
    
    // Remove from hooks
    for (const [hook, listeners] of this.hookListeners) {
      this.hookListeners.set(hook, listeners.filter(l => l.pluginId !== pluginId));
    }
    
    this.plugins.delete(pluginId);
    this.loadOrder = this.loadOrder.filter(id => id !== pluginId);
    
    console.log(`📦 Plugin unregistered: ${pluginId}`);
    return true;
  }
  
  /**
   * Initialize all plugins
   */
  async initAll() {
    // Sort by dependencies
    const sorted = this.topologicalSort();
    
    for (const pluginId of sorted) {
      await this.initPlugin(pluginId);
    }
  }
  
  /**
   * Initialize a single plugin
   * @param {string} pluginId - Plugin ID
   */
  async initPlugin(pluginId) {
    const plugin = this.plugins.get(pluginId);
    if (!plugin) return false;
    
    // Check dependencies
    for (const depId of plugin.dependencies) {
      const dep = this.plugins.get(depId);
      if (!dep || dep.phase !== PluginPhase.ACTIVE) {
        console.error(`Plugin ${pluginId} missing dependency: ${depId}`);
        plugin.phase = PluginPhase.ERROR;
        plugin.error = `Missing dependency: ${depId}`;
        return false;
      }
    }
    
    try {
      plugin.phase = PluginPhase.INITIALIZING;
      await this.emit(PluginHooks.BEFORE_INIT, { pluginId });
      
      await plugin.init();
      
      plugin.phase = PluginPhase.ACTIVE;
      this.loadOrder.push(pluginId);
      
      await this.emit(PluginHooks.AFTER_INIT, { pluginId });
      
      console.log(`📦 Plugin initialized: ${plugin.name}`);
      return true;
      
    } catch (error) {
      plugin.phase = PluginPhase.ERROR;
      plugin.error = error.message;
      console.error(`Plugin ${pluginId} init failed:`, error);
      return false;
    }
  }
  
  /**
   * Topological sort of plugins by dependencies
   */
  topologicalSort() {
    const sorted = [];
    const visited = new Set();
    const visiting = new Set();
    
    const visit = (pluginId) => {
      if (visited.has(pluginId)) return;
      if (visiting.has(pluginId)) {
        throw new Error(`Circular dependency detected: ${pluginId}`);
      }
      
      visiting.add(pluginId);
      
      const plugin = this.plugins.get(pluginId);
      if (plugin) {
        for (const depId of plugin.dependencies) {
          visit(depId);
        }
      }
      
      visiting.delete(pluginId);
      visited.add(pluginId);
      sorted.push(pluginId);
    };
    
    for (const pluginId of this.plugins.keys()) {
      visit(pluginId);
    }
    
    return sorted;
  }
  
  /**
   * Register hook listener
   * @param {string} hook - Hook name
   * @param {string} pluginId - Plugin ID
   * @param {function} handler - Handler function
   */
  on(hook, pluginId, handler) {
    if (!this.hookListeners.has(hook)) {
      this.hookListeners.set(hook, []);
    }
    this.hookListeners.get(hook).push({ pluginId, handler });
  }
  
  /**
   * Emit hook
   * @param {string} hook - Hook name
   * @param {any} data - Hook data
   */
  async emit(hook, data) {
    const listeners = this.hookListeners.get(hook) || [];
    const results = [];
    
    for (const { pluginId, handler } of listeners) {
      const plugin = this.plugins.get(pluginId);
      if (plugin && plugin.phase === PluginPhase.ACTIVE) {
        try {
          const result = await handler.call(plugin, data);
          results.push({ pluginId, result });
        } catch (error) {
          console.error(`Hook ${hook} failed for ${pluginId}:`, error);
        }
      }
    }
    
    return results;
  }
  
  /**
   * Render all active plugins
   * @param {CanvasRenderingContext2D} ctx - Canvas context
   * @param {object} state - Application state
   */
  renderAll(ctx, state) {
    for (const pluginId of this.loadOrder) {
      const plugin = this.plugins.get(pluginId);
      if (plugin && plugin.phase === PluginPhase.ACTIVE) {
        try {
          plugin.render(ctx, state);
        } catch (error) {
          console.error(`Plugin ${pluginId} render failed:`, error);
        }
      }
    }
  }
  
  /**
   * Get plugin by ID
   * @param {string} pluginId - Plugin ID
   */
  get(pluginId) {
    return this.plugins.get(pluginId);
  }
  
  /**
   * Get all plugins
   */
  getAll() {
    return Array.from(this.plugins.values());
  }
  
  /**
   * Get active plugins
   */
  getActive() {
    return this.getAll().filter(p => p.phase === PluginPhase.ACTIVE);
  }
  
  /**
   * Get plugin status
   */
  getStatus() {
    return {
      total: this.plugins.size,
      active: this.getActive().length,
      plugins: this.getAll().map(p => ({
        id: p.id,
        name: p.name,
        version: p.version,
        phase: p.phase,
        error: p.error
      }))
    };
  }
}

// Singleton instance
export const pluginManager = new PluginManager();

/**
 * Create a simple plugin from manifest
 * @param {object} manifest - Plugin manifest
 */
export function createPlugin(manifest) {
  return new Plugin(manifest);
}

/**
 * Example plugin: FPS Counter
 */
export const FPSCounterPlugin = createPlugin({
  id: 'fps-counter',
  name: 'FPS Counter',
  version: '1.0.0',
  description: 'Displays current FPS',
  author: 'TRINITY',
  hooks: {
    [PluginHooks.AFTER_RENDER]: function(data) {
      // Update FPS calculation
    }
  }
});

FPSCounterPlugin.frameCount = 0;
FPSCounterPlugin.lastTime = 0;
FPSCounterPlugin.fps = 0;

FPSCounterPlugin.render = function(ctx, state) {
  const now = performance.now();
  this.frameCount++;
  
  if (now - this.lastTime >= 1000) {
    this.fps = this.frameCount;
    this.frameCount = 0;
    this.lastTime = now;
  }
  
  ctx.fillStyle = 'rgba(0,255,136,0.8)';
  ctx.font = '12px monospace';
  ctx.textAlign = 'left';
  ctx.fillText(`FPS: ${this.fps}`, 10, 20);
};

export default pluginManager;
