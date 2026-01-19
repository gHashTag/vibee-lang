/**
 * TRINITY Table Renderer v16.φ
 * Canvas-based table rendering with φ-optimization
 */

import { PHI, PHI_INV } from './phi.js';

/**
 * Render a table on Canvas
 * @param {CanvasRenderingContext2D} ctx - Canvas context
 * @param {number} x - X position
 * @param {number} y - Y position
 * @param {object} data - Table data { headers: string[], rows: string[][] }
 * @param {object} options - Render options
 * @returns {object} { width, height }
 */
export function renderTable(ctx, x, y, data, options = {}) {
  const {
    cellW = 120,
    cellH = 32,
    fontSize = 14,
    isDark = false
  } = options;
  
  if (!data || !data.headers || !data.rows) {
    throw new Error('Invalid table data: requires headers and rows');
  }
  
  const cols = data.headers.length;
  const rows = data.rows.length;
  const tableW = cols * cellW;
  const tableH = (rows + 1) * cellH;
  
  // Header background
  ctx.fillStyle = isDark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.03)';
  ctx.fillRect(x, y, tableW, cellH);
  
  // Header text
  ctx.fillStyle = isDark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.85)';
  ctx.font = `500 ${fontSize}px Inter, sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  
  data.headers.forEach((header, i) => {
    ctx.fillText(header, x + i * cellW + cellW / 2, y + cellH / 2);
  });
  
  // Rows
  ctx.font = `300 ${fontSize}px Inter, sans-serif`;
  
  data.rows.forEach((row, rowIdx) => {
    const rowY = y + (rowIdx + 1) * cellH;
    
    // Alternating row background
    if (rowIdx % 2 === 1) {
      ctx.fillStyle = isDark ? 'rgba(255,255,255,0.02)' : 'rgba(0,0,0,0.015)';
      ctx.fillRect(x, rowY, tableW, cellH);
    }
    
    ctx.fillStyle = isDark ? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.7)';
    row.forEach((cell, colIdx) => {
      ctx.fillText(String(cell), x + colIdx * cellW + cellW / 2, rowY + cellH / 2);
    });
  });
  
  // Border lines
  ctx.strokeStyle = isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.08)';
  ctx.lineWidth = 0.5;
  
  // Header bottom line
  ctx.beginPath();
  ctx.moveTo(x, y + cellH);
  ctx.lineTo(x + tableW, y + cellH);
  ctx.stroke();
  
  // Outer border
  ctx.strokeRect(x, y, tableW, tableH);
  
  return { width: tableW, height: tableH };
}

/**
 * Calculate optimal cell width using φ
 * @param {number} contentWidth - Available content width
 * @param {number} columns - Number of columns
 * @returns {number} Optimal cell width
 */
export function optimalCellWidth(contentWidth, columns) {
  // Use φ-based distribution
  const baseWidth = contentWidth / columns;
  return Math.round(baseWidth * PHI_INV * PHI);  // Normalize to φ
}

/**
 * Calculate optimal cell height using φ
 * @param {number} fontSize - Font size
 * @returns {number} Optimal cell height
 */
export function optimalCellHeight(fontSize) {
  return Math.round(fontSize * PHI * 1.5);
}
