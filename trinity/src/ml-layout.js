/**
 * TRINITY ML-Guided Layout v21.φ
 * Machine learning optimized layout based on user interactions
 * 
 * Uses φ-weighted features for layout optimization
 * φ² + 1/φ² = 3
 */

const PHI = 1.618033988749895;
const PHI_INV = 0.618033988749895;

/**
 * ML Layout Optimizer
 * Learns from user interactions to optimize layout
 */
export class MLLayoutOptimizer {
  constructor() {
    // Feature weights (φ-initialized)
    this.weights = {
      scrollDepth: PHI_INV,      // How far user scrolls
      timeOnSection: PHI,        // Time spent per section
      clickRate: PHI_INV,        // Click frequency
      returnRate: 1.0,           // Return visits
      deviceType: PHI_INV        // Mobile vs desktop
    };
    
    // Interaction history
    this.history = [];
    this.maxHistory = 1000;
    
    // Section scores
    this.sectionScores = {};
    
    // Learning rate (φ-based)
    this.learningRate = 0.01 * PHI_INV;
    
    // Load saved state
    this.loadState();
  }
  
  /**
   * Record user interaction
   * @param {string} type - Interaction type
   * @param {object} data - Interaction data
   */
  recordInteraction(type, data) {
    const interaction = {
      type,
      data,
      timestamp: Date.now(),
      viewport: { width: window.innerWidth, height: window.innerHeight }
    };
    
    this.history.push(interaction);
    
    // Trim history
    if (this.history.length > this.maxHistory) {
      this.history = this.history.slice(-this.maxHistory);
    }
    
    // Update scores
    this.updateScores(interaction);
    
    // Save state periodically
    if (this.history.length % 10 === 0) {
      this.saveState();
    }
  }
  
  /**
   * Record scroll event
   * @param {number} scrollY - Scroll position
   * @param {number} maxScroll - Maximum scroll
   */
  recordScroll(scrollY, maxScroll) {
    const depth = maxScroll > 0 ? scrollY / maxScroll : 0;
    this.recordInteraction('scroll', { scrollY, maxScroll, depth });
  }
  
  /**
   * Record section view
   * @param {string} section - Section name
   * @param {number} duration - View duration in ms
   */
  recordSectionView(section, duration) {
    this.recordInteraction('view', { section, duration });
    
    // Update section score
    if (!this.sectionScores[section]) {
      this.sectionScores[section] = { views: 0, totalTime: 0, score: 1.0 };
    }
    
    this.sectionScores[section].views++;
    this.sectionScores[section].totalTime += duration;
    
    // Calculate engagement score
    const avgTime = this.sectionScores[section].totalTime / this.sectionScores[section].views;
    this.sectionScores[section].score = Math.min(2.0, 1.0 + (avgTime / 10000) * PHI_INV);
  }
  
  /**
   * Record click event
   * @param {string} target - Click target
   * @param {object} position - Click position
   */
  recordClick(target, position) {
    this.recordInteraction('click', { target, position });
  }
  
  /**
   * Update feature weights based on interaction
   * @param {object} interaction - Interaction data
   */
  updateScores(interaction) {
    // Simple gradient update
    switch (interaction.type) {
      case 'scroll':
        // Reward deep scrolling
        if (interaction.data.depth > 0.8) {
          this.weights.scrollDepth *= (1 + this.learningRate);
        }
        break;
        
      case 'view':
        // Reward long section views
        if (interaction.data.duration > 5000) {
          this.weights.timeOnSection *= (1 + this.learningRate);
        }
        break;
        
      case 'click':
        // Reward clicks
        this.weights.clickRate *= (1 + this.learningRate);
        break;
    }
    
    // Normalize weights
    this.normalizeWeights();
  }
  
  /**
   * Normalize weights to sum to φ
   */
  normalizeWeights() {
    const sum = Object.values(this.weights).reduce((a, b) => a + b, 0);
    const target = PHI * 3; // Target sum
    
    for (const key of Object.keys(this.weights)) {
      this.weights[key] = (this.weights[key] / sum) * target;
    }
  }
  
  /**
   * Get optimized section order
   * @param {string[]} sections - Section names
   * @returns {string[]} Optimized order
   */
  getOptimizedOrder(sections) {
    // Score each section
    const scored = sections.map(section => ({
      section,
      score: this.getSectionScore(section)
    }));
    
    // Sort by score (descending)
    scored.sort((a, b) => b.score - a.score);
    
    return scored.map(s => s.section);
  }
  
  /**
   * Get section score
   * @param {string} section - Section name
   * @returns {number} Score
   */
  getSectionScore(section) {
    const data = this.sectionScores[section];
    if (!data) return 1.0;
    
    return data.score * this.weights.timeOnSection;
  }
  
  /**
   * Get optimized section height
   * @param {string} section - Section name
   * @param {number} baseHeight - Base height
   * @returns {number} Optimized height
   */
  getOptimizedHeight(section, baseHeight) {
    const score = this.getSectionScore(section);
    
    // Scale height by score (φ-bounded)
    const scale = Math.max(PHI_INV, Math.min(PHI, score));
    return Math.round(baseHeight * scale);
  }
  
  /**
   * Get layout recommendations
   * @returns {object} Recommendations
   */
  getRecommendations() {
    const totalViews = this.history.filter(h => h.type === 'view').length;
    const avgScrollDepth = this.history
      .filter(h => h.type === 'scroll')
      .reduce((sum, h) => sum + (h.data.depth || 0), 0) / 
      Math.max(1, this.history.filter(h => h.type === 'scroll').length);
    
    return {
      // Top sections by engagement
      topSections: Object.entries(this.sectionScores)
        .sort((a, b) => b[1].score - a[1].score)
        .slice(0, 5)
        .map(([name, data]) => ({ name, score: data.score.toFixed(2) })),
      
      // Scroll behavior
      scrollBehavior: {
        avgDepth: (avgScrollDepth * 100).toFixed(1) + '%',
        recommendation: avgScrollDepth < 0.5 ? 
          'Consider shorter content or better hooks' : 
          'Good engagement depth'
      },
      
      // Feature weights
      weights: Object.fromEntries(
        Object.entries(this.weights).map(([k, v]) => [k, v.toFixed(3)])
      ),
      
      // Stats
      stats: {
        totalInteractions: this.history.length,
        totalViews,
        sectionsTracked: Object.keys(this.sectionScores).length
      }
    };
  }
  
  /**
   * Save state to localStorage
   */
  saveState() {
    try {
      const state = {
        weights: this.weights,
        sectionScores: this.sectionScores,
        historyLength: this.history.length
      };
      localStorage.setItem('trinity-ml-layout', JSON.stringify(state));
    } catch (e) {
      console.warn('ML Layout: Failed to save state', e);
    }
  }
  
  /**
   * Load state from localStorage
   */
  loadState() {
    try {
      const saved = localStorage.getItem('trinity-ml-layout');
      if (saved) {
        const state = JSON.parse(saved);
        this.weights = { ...this.weights, ...state.weights };
        this.sectionScores = state.sectionScores || {};
        console.log('ML Layout: Loaded state', state);
      }
    } catch (e) {
      console.warn('ML Layout: Failed to load state', e);
    }
  }
  
  /**
   * Reset learning
   */
  reset() {
    this.history = [];
    this.sectionScores = {};
    this.weights = {
      scrollDepth: PHI_INV,
      timeOnSection: PHI,
      clickRate: PHI_INV,
      returnRate: 1.0,
      deviceType: PHI_INV
    };
    localStorage.removeItem('trinity-ml-layout');
    console.log('ML Layout: Reset');
  }
}

// Singleton instance
export const mlLayout = new MLLayoutOptimizer();

export default mlLayout;
