/**
 * TRINITY Table Renderer Tests v16.φ
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderTable, optimalCellWidth, optimalCellHeight } from '../src/table.js';
import { PHI } from '../src/phi.js';

// Mock Canvas context
const createMockContext = () => ({
  fillStyle: '',
  strokeStyle: '',
  lineWidth: 1,
  font: '',
  textAlign: '',
  textBaseline: '',
  fillRect: vi.fn(),
  strokeRect: vi.fn(),
  fillText: vi.fn(),
  beginPath: vi.fn(),
  moveTo: vi.fn(),
  lineTo: vi.fn(),
  stroke: vi.fn()
});

describe('Table Renderer v16.φ', () => {
  let ctx;
  
  beforeEach(() => {
    ctx = createMockContext();
  });
  
  describe('renderTable()', () => {
    it('should render a basic table', () => {
      const data = {
        headers: ['A', 'B', 'C'],
        rows: [['1', '2', '3']]
      };
      
      const result = renderTable(ctx, 0, 0, data);
      
      expect(result.width).toBe(360);  // 3 × 120
      expect(result.height).toBe(64);  // 2 × 32
    });
    
    it('should call fillText for each cell', () => {
      const data = {
        headers: ['A', 'B'],
        rows: [['1', '2'], ['3', '4']]
      };
      
      renderTable(ctx, 0, 0, data);
      
      // 2 headers + 4 cells = 6 fillText calls
      expect(ctx.fillText).toHaveBeenCalledTimes(6);
    });
    
    it('should throw on invalid data', () => {
      expect(() => renderTable(ctx, 0, 0, null)).toThrow();
      expect(() => renderTable(ctx, 0, 0, {})).toThrow();
      expect(() => renderTable(ctx, 0, 0, { headers: [] })).toThrow();
    });
    
    it('should handle custom cell dimensions', () => {
      const data = {
        headers: ['A', 'B'],
        rows: [['1', '2']]
      };
      
      const result = renderTable(ctx, 0, 0, data, { cellW: 100, cellH: 40 });
      
      expect(result.width).toBe(200);  // 2 × 100
      expect(result.height).toBe(80);  // 2 × 40
    });
    
    it('should handle dark mode', () => {
      const data = {
        headers: ['A'],
        rows: [['1']]
      };
      
      renderTable(ctx, 0, 0, data, { isDark: true });
      
      // Should set dark mode colors
      expect(ctx.fillRect).toHaveBeenCalled();
    });
    
    it('should draw alternating row backgrounds', () => {
      const data = {
        headers: ['A'],
        rows: [['1'], ['2'], ['3']]
      };
      
      renderTable(ctx, 0, 0, data);
      
      // Header bg + row 1 bg (odd rows get background)
      expect(ctx.fillRect.mock.calls.length).toBeGreaterThanOrEqual(2);
    });
    
    it('should draw border lines', () => {
      const data = {
        headers: ['A'],
        rows: [['1']]
      };
      
      renderTable(ctx, 0, 0, data);
      
      expect(ctx.beginPath).toHaveBeenCalled();
      expect(ctx.stroke).toHaveBeenCalled();
      expect(ctx.strokeRect).toHaveBeenCalled();
    });
  });
  
  describe('optimalCellWidth()', () => {
    it('should calculate φ-based cell width', () => {
      const width = optimalCellWidth(600, 5);
      expect(width).toBeGreaterThan(0);
      expect(width).toBeLessThan(600);
    });
    
    it('should scale with content width', () => {
      const w1 = optimalCellWidth(600, 5);
      const w2 = optimalCellWidth(1200, 5);
      expect(w2).toBeGreaterThan(w1);
    });
    
    it('should scale inversely with columns', () => {
      const w1 = optimalCellWidth(600, 3);
      const w2 = optimalCellWidth(600, 6);
      expect(w1).toBeGreaterThan(w2);
    });
  });
  
  describe('optimalCellHeight()', () => {
    it('should calculate φ-based cell height', () => {
      const height = optimalCellHeight(14);
      expect(height).toBeGreaterThan(14);
      expect(height).toBeCloseTo(14 * PHI * 1.5, 0);
    });
    
    it('should scale with font size', () => {
      const h1 = optimalCellHeight(12);
      const h2 = optimalCellHeight(16);
      expect(h2).toBeGreaterThan(h1);
    });
  });
  
  describe('Performance', () => {
    it('should render 1000 tables in <500ms', () => {
      const data = {
        headers: ['A', 'B', 'C', 'D', 'E'],
        rows: [
          ['1', '2', '3', '4', '5'],
          ['6', '7', '8', '9', '10'],
          ['11', '12', '13', '14', '15']
        ]
      };
      
      const start = performance.now();
      for (let i = 0; i < 1000; i++) {
        renderTable(ctx, 0, 0, data);
      }
      const elapsed = performance.now() - start;
      
      expect(elapsed).toBeLessThan(500);
    });
  });
});
