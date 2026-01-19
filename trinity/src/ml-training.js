/**
 * TRINITY ML Layout Training v23.φ
 * Training data collection and model optimization
 * 
 * φ² + 1/φ² = 3
 */

const PHI = 1.618033988749895;
const PHI_INV = 0.618033988749895;

/**
 * Training data collector
 * Collects user interaction data for ML model training
 */
export class TrainingDataCollector {
  constructor() {
    this.sessions = [];
    this.currentSession = null;
    this.maxSessions = 100;
    this.storageKey = 'trinity-ml-training';
    
    this.loadData();
  }
  
  /**
   * Start new session
   */
  startSession() {
    this.currentSession = {
      id: `session-${Date.now()}`,
      startTime: Date.now(),
      endTime: null,
      device: this.getDeviceInfo(),
      interactions: [],
      sectionViews: {},
      scrollEvents: [],
      clicks: [],
      finalScroll: 0
    };
  }
  
  /**
   * End current session
   */
  endSession() {
    if (!this.currentSession) return;
    
    this.currentSession.endTime = Date.now();
    this.currentSession.duration = this.currentSession.endTime - this.currentSession.startTime;
    
    this.sessions.push(this.currentSession);
    
    // Trim old sessions
    if (this.sessions.length > this.maxSessions) {
      this.sessions = this.sessions.slice(-this.maxSessions);
    }
    
    this.saveData();
    this.currentSession = null;
  }
  
  /**
   * Record scroll event
   */
  recordScroll(scrollY, maxScroll) {
    if (!this.currentSession) return;
    
    const depth = maxScroll > 0 ? scrollY / maxScroll : 0;
    
    this.currentSession.scrollEvents.push({
      timestamp: Date.now(),
      scrollY,
      maxScroll,
      depth
    });
    
    this.currentSession.finalScroll = scrollY;
  }
  
  /**
   * Record section view
   */
  recordSectionView(section, enterTime, exitTime) {
    if (!this.currentSession) return;
    
    const duration = exitTime - enterTime;
    
    if (!this.currentSession.sectionViews[section]) {
      this.currentSession.sectionViews[section] = {
        views: 0,
        totalTime: 0,
        entries: []
      };
    }
    
    this.currentSession.sectionViews[section].views++;
    this.currentSession.sectionViews[section].totalTime += duration;
    this.currentSession.sectionViews[section].entries.push({
      enterTime,
      exitTime,
      duration
    });
  }
  
  /**
   * Record click
   */
  recordClick(target, x, y) {
    if (!this.currentSession) return;
    
    this.currentSession.clicks.push({
      timestamp: Date.now(),
      target,
      x,
      y
    });
  }
  
  /**
   * Get device info
   */
  getDeviceInfo() {
    return {
      width: window.innerWidth,
      height: window.innerHeight,
      pixelRatio: window.devicePixelRatio || 1,
      isMobile: window.innerWidth < 768,
      isTablet: window.innerWidth >= 768 && window.innerWidth < 1024,
      userAgent: navigator.userAgent.substring(0, 100)
    };
  }
  
  /**
   * Save data to localStorage
   */
  saveData() {
    try {
      const data = {
        sessions: this.sessions,
        lastUpdated: Date.now()
      };
      localStorage.setItem(this.storageKey, JSON.stringify(data));
    } catch (e) {
      console.warn('ML Training: Failed to save data', e);
    }
  }
  
  /**
   * Load data from localStorage
   */
  loadData() {
    try {
      const saved = localStorage.getItem(this.storageKey);
      if (saved) {
        const data = JSON.parse(saved);
        this.sessions = data.sessions || [];
      }
    } catch (e) {
      console.warn('ML Training: Failed to load data', e);
    }
  }
  
  /**
   * Get training statistics
   */
  getStats() {
    const totalSessions = this.sessions.length;
    const totalDuration = this.sessions.reduce((sum, s) => sum + (s.duration || 0), 0);
    const avgDuration = totalSessions > 0 ? totalDuration / totalSessions : 0;
    
    // Aggregate section data
    const sectionStats = {};
    this.sessions.forEach(session => {
      Object.entries(session.sectionViews || {}).forEach(([section, data]) => {
        if (!sectionStats[section]) {
          sectionStats[section] = { views: 0, totalTime: 0 };
        }
        sectionStats[section].views += data.views;
        sectionStats[section].totalTime += data.totalTime;
      });
    });
    
    // Calculate engagement scores
    const sectionScores = {};
    Object.entries(sectionStats).forEach(([section, data]) => {
      const avgTime = data.views > 0 ? data.totalTime / data.views : 0;
      sectionScores[section] = Math.min(2.0, 1.0 + (avgTime / 10000) * PHI_INV);
    });
    
    return {
      totalSessions,
      totalDuration,
      avgDuration: Math.round(avgDuration),
      sectionStats,
      sectionScores
    };
  }
  
  /**
   * Export training data
   */
  exportData() {
    return {
      version: 'v23.φ',
      exportedAt: Date.now(),
      sessions: this.sessions,
      stats: this.getStats()
    };
  }
  
  /**
   * Clear all data
   */
  clearData() {
    this.sessions = [];
    this.currentSession = null;
    localStorage.removeItem(this.storageKey);
  }
}

/**
 * ML Model Trainer
 * Trains layout optimization model from collected data
 */
export class MLModelTrainer {
  constructor() {
    this.weights = {
      scrollDepth: PHI_INV,
      timeOnSection: PHI,
      clickRate: PHI_INV,
      returnRate: 1.0,
      deviceType: PHI_INV
    };
    
    this.learningRate = 0.01 * PHI_INV;
    this.momentum = 0.9;
    this.previousGradients = {};
  }
  
  /**
   * Train model on session data
   */
  train(sessions) {
    if (sessions.length === 0) return;
    
    // Calculate gradients from session data
    const gradients = this.calculateGradients(sessions);
    
    // Apply momentum
    Object.keys(gradients).forEach(key => {
      const prevGrad = this.previousGradients[key] || 0;
      gradients[key] = this.momentum * prevGrad + (1 - this.momentum) * gradients[key];
      this.previousGradients[key] = gradients[key];
    });
    
    // Update weights
    Object.keys(this.weights).forEach(key => {
      if (gradients[key] !== undefined) {
        this.weights[key] += this.learningRate * gradients[key];
        // Clamp weights
        this.weights[key] = Math.max(0.1, Math.min(2.0, this.weights[key]));
      }
    });
    
    // Normalize weights
    this.normalizeWeights();
    
    return this.weights;
  }
  
  /**
   * Calculate gradients from sessions
   */
  calculateGradients(sessions) {
    const gradients = {
      scrollDepth: 0,
      timeOnSection: 0,
      clickRate: 0,
      returnRate: 0,
      deviceType: 0
    };
    
    sessions.forEach(session => {
      // Scroll depth gradient
      const scrollEvents = session.scrollEvents || [];
      if (scrollEvents.length > 0) {
        const avgDepth = scrollEvents.reduce((sum, e) => sum + e.depth, 0) / scrollEvents.length;
        gradients.scrollDepth += avgDepth > 0.5 ? 0.1 : -0.05;
      }
      
      // Time on section gradient
      const sectionViews = session.sectionViews || {};
      Object.values(sectionViews).forEach(data => {
        const avgTime = data.views > 0 ? data.totalTime / data.views : 0;
        gradients.timeOnSection += avgTime > 5000 ? 0.1 : -0.02;
      });
      
      // Click rate gradient
      const clicks = session.clicks || [];
      const duration = session.duration || 1;
      const clickRate = clicks.length / (duration / 60000); // clicks per minute
      gradients.clickRate += clickRate > 2 ? 0.1 : -0.02;
      
      // Device type gradient
      if (session.device?.isMobile) {
        gradients.deviceType += 0.05;
      }
    });
    
    // Normalize gradients
    const count = sessions.length;
    Object.keys(gradients).forEach(key => {
      gradients[key] /= count;
    });
    
    return gradients;
  }
  
  /**
   * Normalize weights to sum to φ × 3
   */
  normalizeWeights() {
    const sum = Object.values(this.weights).reduce((a, b) => a + b, 0);
    const target = PHI * 3;
    
    Object.keys(this.weights).forEach(key => {
      this.weights[key] = (this.weights[key] / sum) * target;
    });
  }
  
  /**
   * Get optimized section heights
   */
  getOptimizedHeights(baseHeights, sectionScores) {
    const optimized = {};
    
    Object.entries(baseHeights).forEach(([section, baseHeight]) => {
      const score = sectionScores[section] || 1.0;
      const weightedScore = score * this.weights.timeOnSection;
      const scale = Math.max(PHI_INV, Math.min(PHI, weightedScore));
      optimized[section] = Math.round(baseHeight * scale);
    });
    
    return optimized;
  }
  
  /**
   * Export model
   */
  exportModel() {
    return {
      version: 'v23.φ',
      weights: this.weights,
      learningRate: this.learningRate,
      momentum: this.momentum
    };
  }
  
  /**
   * Import model
   */
  importModel(model) {
    if (model.weights) {
      this.weights = { ...this.weights, ...model.weights };
    }
    if (model.learningRate) {
      this.learningRate = model.learningRate;
    }
    if (model.momentum) {
      this.momentum = model.momentum;
    }
  }
}

// Singleton instances
export const trainingCollector = new TrainingDataCollector();
export const modelTrainer = new MLModelTrainer();

// Auto-start session on page load
if (typeof window !== 'undefined') {
  window.addEventListener('load', () => {
    trainingCollector.startSession();
  });
  
  window.addEventListener('beforeunload', () => {
    trainingCollector.endSession();
  });
}

export default {
  trainingCollector,
  modelTrainer
};
