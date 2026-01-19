/**
 * TRINITY Diagram Renderer v17.φ
 * Canvas-based flowchart and sequence diagram rendering
 */

import { PHI, PHI_INV } from './phi.js';

/**
 * Render a flowchart diagram
 * @param {CanvasRenderingContext2D} ctx - Canvas context
 * @param {number} x - X position
 * @param {number} y - Y position
 * @param {Array} nodes - Node definitions
 * @param {Array} edges - Edge definitions
 * @param {object} options - Render options
 * @returns {object} { width, height }
 */
export function renderFlowchart(ctx, x, y, nodes, edges, options = {}) {
  const {
    nodeW = 120,
    nodeH = 40,
    fontSize = 13,
    isDark = false,
    direction = 'TB'
  } = options;
  
  if (!nodes || !Array.isArray(nodes)) {
    throw new Error('Invalid nodes: requires array');
  }
  
  const colors = {
    node: isDark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.03)',
    border: isDark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)',
    text: isDark ? 'rgba(255,255,255,0.85)' : 'rgba(0,0,0,0.8)',
    edge: isDark ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.25)',
    accent: '#ffd700'
  };
  
  // φ-based gaps
  const gapX = nodeW * PHI;
  const gapY = nodeH * PHI * 1.5;
  
  // Calculate positions
  const nodePositions = {};
  nodes.forEach((node, i) => {
    const row = node.row ?? Math.floor(i / 3);
    const col = node.col ?? (i % 3);
    nodePositions[node.id] = {
      x: direction === 'LR' ? x + row * gapX : x + col * gapX,
      y: direction === 'LR' ? y + col * gapY : y + row * gapY,
      ...node
    };
  });
  
  // Draw edges
  ctx.strokeStyle = colors.edge;
  ctx.lineWidth = 1.5;
  
  (edges || []).forEach(edge => {
    const from = nodePositions[edge.from];
    const to = nodePositions[edge.to];
    if (!from || !to) return;
    
    const fromX = from.x + nodeW / 2;
    const fromY = from.y + nodeH;
    const toX = to.x + nodeW / 2;
    const toY = to.y;
    
    ctx.beginPath();
    ctx.moveTo(fromX, fromY);
    
    // Bezier curve
    const midY = (fromY + toY) / 2;
    ctx.bezierCurveTo(fromX, midY, toX, midY, toX, toY);
    ctx.stroke();
    
    // Arrow head
    const arrowSize = 6;
    ctx.beginPath();
    ctx.moveTo(toX, toY);
    ctx.lineTo(toX - arrowSize, toY - arrowSize);
    ctx.lineTo(toX + arrowSize, toY - arrowSize);
    ctx.closePath();
    ctx.fillStyle = colors.edge;
    ctx.fill();
  });
  
  // Draw nodes
  nodes.forEach(node => {
    const pos = nodePositions[node.id];
    const nx = pos.x;
    const ny = pos.y;
    
    ctx.fillStyle = node.highlight ? 'rgba(255,215,0,0.15)' : colors.node;
    ctx.strokeStyle = node.highlight ? colors.accent : colors.border;
    ctx.lineWidth = node.highlight ? 2 : 1;
    
    ctx.beginPath();
    if (node.shape === 'diamond') {
      ctx.moveTo(nx + nodeW / 2, ny);
      ctx.lineTo(nx + nodeW, ny + nodeH / 2);
      ctx.lineTo(nx + nodeW / 2, ny + nodeH);
      ctx.lineTo(nx, ny + nodeH / 2);
      ctx.closePath();
    } else if (node.shape === 'circle') {
      ctx.ellipse(nx + nodeW / 2, ny + nodeH / 2, nodeW / 2, nodeH / 2, 0, 0, Math.PI * 2);
    } else {
      ctx.roundRect(nx, ny, nodeW, nodeH, nodeH / PHI / 2);
    }
    
    ctx.fill();
    ctx.stroke();
    
    // Node text
    ctx.fillStyle = node.highlight ? colors.accent : colors.text;
    ctx.font = `500 ${fontSize}px Inter, sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(node.label, nx + nodeW / 2, ny + nodeH / 2);
  });
  
  // Calculate bounds
  let maxX = 0, maxY = 0;
  Object.values(nodePositions).forEach(pos => {
    maxX = Math.max(maxX, pos.x + nodeW);
    maxY = Math.max(maxY, pos.y + nodeH);
  });
  
  return { width: maxX - x, height: maxY - y };
}

/**
 * Render a sequence diagram
 * @param {CanvasRenderingContext2D} ctx - Canvas context
 * @param {number} x - X position
 * @param {number} y - Y position
 * @param {Array} actors - Actor definitions
 * @param {Array} messages - Message definitions
 * @param {object} options - Render options
 * @returns {object} { width, height }
 */
export function renderSequence(ctx, x, y, actors, messages, options = {}) {
  const {
    actorW = 100,
    actorH = 30,
    fontSize = 12,
    isDark = false
  } = options;
  
  if (!actors || !Array.isArray(actors)) {
    throw new Error('Invalid actors: requires array');
  }
  
  const colors = {
    actor: isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)',
    border: isDark ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.2)',
    text: isDark ? 'rgba(255,255,255,0.85)' : 'rgba(0,0,0,0.8)',
    line: isDark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)',
    arrow: isDark ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.4)'
  };
  
  const gapX = actorW * PHI;
  const msgGap = 35;
  
  // Draw actors
  const actorPositions = {};
  actors.forEach((actor, i) => {
    const ax = x + i * gapX;
    actorPositions[actor.id] = ax + actorW / 2;
    
    ctx.fillStyle = colors.actor;
    ctx.strokeStyle = colors.border;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.roundRect(ax, y, actorW, actorH, 4);
    ctx.fill();
    ctx.stroke();
    
    ctx.fillStyle = colors.text;
    ctx.font = `500 ${fontSize}px Inter, sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(actor.name, ax + actorW / 2, y + actorH / 2);
    
    // Lifeline
    ctx.strokeStyle = colors.line;
    ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.moveTo(ax + actorW / 2, y + actorH);
    ctx.lineTo(ax + actorW / 2, y + actorH + (messages?.length || 0) * msgGap + 20);
    ctx.stroke();
    ctx.setLineDash([]);
  });
  
  // Draw messages
  (messages || []).forEach((msg, i) => {
    const my = y + actorH + 20 + i * msgGap;
    const fromX = actorPositions[msg.from];
    const toX = actorPositions[msg.to];
    
    if (!fromX || !toX) return;
    
    ctx.strokeStyle = colors.arrow;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(fromX, my);
    ctx.lineTo(toX, my);
    ctx.stroke();
    
    // Arrow head
    const dir = toX > fromX ? 1 : -1;
    ctx.beginPath();
    ctx.moveTo(toX, my);
    ctx.lineTo(toX - dir * 8, my - 4);
    ctx.lineTo(toX - dir * 8, my + 4);
    ctx.closePath();
    ctx.fillStyle = colors.arrow;
    ctx.fill();
    
    // Label
    ctx.fillStyle = colors.text;
    ctx.font = `${fontSize - 1}px Inter, sans-serif`;
    ctx.textAlign = 'center';
    ctx.fillText(msg.label, (fromX + toX) / 2, my - 8);
  });
  
  return {
    width: actors.length * gapX,
    height: actorH + (messages?.length || 0) * msgGap + 40
  };
}

/**
 * Calculate optimal node width using φ
 * @param {string} label - Node label
 * @param {number} fontSize - Font size
 * @returns {number} Optimal node width
 */
export function optimalNodeWidth(label, fontSize) {
  const charWidth = fontSize * 0.6;
  const textWidth = label.length * charWidth;
  return Math.round(textWidth * PHI);
}
