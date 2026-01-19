/**
 * TRINITY Real-time Collaboration v21.φ
 * WebSocket + CRDT for conflict-free collaboration
 * 
 * φ² + 1/φ² = 3
 */

const PHI = 1.618033988749895;

/**
 * Simple CRDT Counter
 * Conflict-free replicated data type for counters
 */
export class CRDTCounter {
  constructor(nodeId) {
    this.nodeId = nodeId;
    this.increments = {};  // nodeId -> count
    this.decrements = {};  // nodeId -> count
  }
  
  increment() {
    this.increments[this.nodeId] = (this.increments[this.nodeId] || 0) + 1;
  }
  
  decrement() {
    this.decrements[this.nodeId] = (this.decrements[this.nodeId] || 0) + 1;
  }
  
  value() {
    const inc = Object.values(this.increments).reduce((a, b) => a + b, 0);
    const dec = Object.values(this.decrements).reduce((a, b) => a + b, 0);
    return inc - dec;
  }
  
  merge(other) {
    for (const [nodeId, count] of Object.entries(other.increments)) {
      this.increments[nodeId] = Math.max(this.increments[nodeId] || 0, count);
    }
    for (const [nodeId, count] of Object.entries(other.decrements)) {
      this.decrements[nodeId] = Math.max(this.decrements[nodeId] || 0, count);
    }
  }
  
  toJSON() {
    return { increments: this.increments, decrements: this.decrements };
  }
  
  static fromJSON(nodeId, json) {
    const counter = new CRDTCounter(nodeId);
    counter.increments = json.increments || {};
    counter.decrements = json.decrements || {};
    return counter;
  }
}

/**
 * Simple CRDT LWW Register (Last-Writer-Wins)
 */
export class CRDTRegister {
  constructor(nodeId) {
    this.nodeId = nodeId;
    this.value = null;
    this.timestamp = 0;
  }
  
  set(value) {
    this.value = value;
    this.timestamp = Date.now();
  }
  
  get() {
    return this.value;
  }
  
  merge(other) {
    if (other.timestamp > this.timestamp) {
      this.value = other.value;
      this.timestamp = other.timestamp;
    }
  }
  
  toJSON() {
    return { value: this.value, timestamp: this.timestamp };
  }
  
  static fromJSON(nodeId, json) {
    const register = new CRDTRegister(nodeId);
    register.value = json.value;
    register.timestamp = json.timestamp || 0;
    return register;
  }
}

/**
 * Collaboration Manager
 * Handles WebSocket connection and state synchronization
 */
export class CollaborationManager {
  constructor(options = {}) {
    this.nodeId = options.nodeId || this.generateNodeId();
    this.wsUrl = options.wsUrl || null;
    this.ws = null;
    this.connected = false;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.reconnectDelay = 1000;
    
    // State
    this.state = {
      scrollPosition: new CRDTRegister(this.nodeId),
      activeSection: new CRDTRegister(this.nodeId),
      theme: new CRDTRegister(this.nodeId),
      viewCount: new CRDTCounter(this.nodeId)
    };
    
    // Cursors of other users
    this.cursors = new Map();
    
    // Event handlers
    this.handlers = {
      connect: [],
      disconnect: [],
      stateChange: [],
      cursorMove: [],
      userJoin: [],
      userLeave: []
    };
  }
  
  /**
   * Generate unique node ID
   */
  generateNodeId() {
    return `node-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
  
  /**
   * Connect to collaboration server
   * @param {string} wsUrl - WebSocket URL
   */
  async connect(wsUrl) {
    if (this.ws) {
      this.ws.close();
    }
    
    this.wsUrl = wsUrl;
    
    return new Promise((resolve, reject) => {
      try {
        this.ws = new WebSocket(wsUrl);
        
        this.ws.onopen = () => {
          this.connected = true;
          this.reconnectAttempts = 0;
          console.log('🔗 Collaboration connected');
          
          // Send join message
          this.send({
            type: 'join',
            nodeId: this.nodeId,
            state: this.getStateSnapshot()
          });
          
          this.emit('connect');
          resolve();
        };
        
        this.ws.onclose = () => {
          this.connected = false;
          console.log('🔗 Collaboration disconnected');
          this.emit('disconnect');
          
          // Attempt reconnect
          this.attemptReconnect();
        };
        
        this.ws.onerror = (error) => {
          console.error('🔗 Collaboration error:', error);
          reject(error);
        };
        
        this.ws.onmessage = (event) => {
          this.handleMessage(JSON.parse(event.data));
        };
        
      } catch (error) {
        reject(error);
      }
    });
  }
  
  /**
   * Attempt to reconnect
   */
  attemptReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.log('🔗 Max reconnect attempts reached');
      return;
    }
    
    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(PHI, this.reconnectAttempts - 1);
    
    console.log(`🔗 Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);
    
    setTimeout(() => {
      if (!this.connected && this.wsUrl) {
        this.connect(this.wsUrl).catch(() => {});
      }
    }, delay);
  }
  
  /**
   * Send message to server
   * @param {object} message - Message to send
   */
  send(message) {
    if (this.ws && this.connected) {
      this.ws.send(JSON.stringify(message));
    }
  }
  
  /**
   * Handle incoming message
   * @param {object} message - Received message
   */
  handleMessage(message) {
    switch (message.type) {
      case 'state':
        this.mergeState(message.state);
        this.emit('stateChange', this.state);
        break;
        
      case 'cursor':
        this.cursors.set(message.nodeId, {
          x: message.x,
          y: message.y,
          timestamp: Date.now()
        });
        this.emit('cursorMove', { nodeId: message.nodeId, x: message.x, y: message.y });
        break;
        
      case 'join':
        console.log('🔗 User joined:', message.nodeId);
        this.emit('userJoin', { nodeId: message.nodeId });
        break;
        
      case 'leave':
        console.log('🔗 User left:', message.nodeId);
        this.cursors.delete(message.nodeId);
        this.emit('userLeave', { nodeId: message.nodeId });
        break;
    }
  }
  
  /**
   * Merge remote state
   * @param {object} remoteState - State from server
   */
  mergeState(remoteState) {
    if (remoteState.scrollPosition) {
      this.state.scrollPosition.merge(remoteState.scrollPosition);
    }
    if (remoteState.activeSection) {
      this.state.activeSection.merge(remoteState.activeSection);
    }
    if (remoteState.theme) {
      this.state.theme.merge(remoteState.theme);
    }
    if (remoteState.viewCount) {
      this.state.viewCount.merge(
        CRDTCounter.fromJSON(this.nodeId, remoteState.viewCount)
      );
    }
  }
  
  /**
   * Get state snapshot
   */
  getStateSnapshot() {
    return {
      scrollPosition: this.state.scrollPosition.toJSON(),
      activeSection: this.state.activeSection.toJSON(),
      theme: this.state.theme.toJSON(),
      viewCount: this.state.viewCount.toJSON()
    };
  }
  
  /**
   * Update scroll position
   * @param {number} scrollY - Scroll position
   */
  updateScroll(scrollY) {
    this.state.scrollPosition.set(scrollY);
    this.send({
      type: 'state',
      state: { scrollPosition: this.state.scrollPosition.toJSON() }
    });
  }
  
  /**
   * Update active section
   * @param {string} section - Section name
   */
  updateSection(section) {
    this.state.activeSection.set(section);
    this.send({
      type: 'state',
      state: { activeSection: this.state.activeSection.toJSON() }
    });
  }
  
  /**
   * Update cursor position
   * @param {number} x - X position
   * @param {number} y - Y position
   */
  updateCursor(x, y) {
    this.send({
      type: 'cursor',
      nodeId: this.nodeId,
      x, y
    });
  }
  
  /**
   * Increment view count
   */
  incrementViews() {
    this.state.viewCount.increment();
    this.send({
      type: 'state',
      state: { viewCount: this.state.viewCount.toJSON() }
    });
  }
  
  /**
   * Get view count
   */
  getViewCount() {
    return this.state.viewCount.value();
  }
  
  /**
   * Get other users' cursors
   */
  getCursors() {
    // Clean up old cursors (>5 seconds)
    const now = Date.now();
    for (const [nodeId, cursor] of this.cursors) {
      if (now - cursor.timestamp > 5000) {
        this.cursors.delete(nodeId);
      }
    }
    return Array.from(this.cursors.entries()).map(([nodeId, cursor]) => ({
      nodeId,
      ...cursor
    }));
  }
  
  /**
   * Register event handler
   * @param {string} event - Event name
   * @param {function} handler - Handler function
   */
  on(event, handler) {
    if (this.handlers[event]) {
      this.handlers[event].push(handler);
    }
  }
  
  /**
   * Emit event
   * @param {string} event - Event name
   * @param {any} data - Event data
   */
  emit(event, data) {
    if (this.handlers[event]) {
      this.handlers[event].forEach(handler => handler(data));
    }
  }
  
  /**
   * Disconnect
   */
  disconnect() {
    if (this.ws) {
      this.send({ type: 'leave', nodeId: this.nodeId });
      this.ws.close();
      this.ws = null;
    }
    this.connected = false;
  }
}

// Singleton instance
export const collaboration = new CollaborationManager();

export default collaboration;
