/**
 * TRINITY Diagram Renderer Tests v17.φ
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderFlowchart, renderSequence, optimalNodeWidth } from '../src/diagram.js';
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
  bezierCurveTo: vi.fn(),
  stroke: vi.fn(),
  fill: vi.fn(),
  closePath: vi.fn(),
  ellipse: vi.fn(),
  roundRect: vi.fn(),
  setLineDash: vi.fn()
});

describe('Flowchart Renderer v17.φ', () => {
  let ctx;
  
  beforeEach(() => {
    ctx = createMockContext();
  });
  
  describe('renderFlowchart()', () => {
    it('should render a basic flowchart', () => {
      const nodes = [
        { id: 'a', label: 'A', row: 0, col: 0 },
        { id: 'b', label: 'B', row: 1, col: 0 }
      ];
      const edges = [{ from: 'a', to: 'b' }];
      
      const result = renderFlowchart(ctx, 0, 0, nodes, edges);
      
      expect(result.width).toBeGreaterThan(0);
      expect(result.height).toBeGreaterThan(0);
    });
    
    it('should throw on invalid nodes', () => {
      expect(() => renderFlowchart(ctx, 0, 0, null, [])).toThrow();
      expect(() => renderFlowchart(ctx, 0, 0, 'invalid', [])).toThrow();
    });
    
    it('should handle empty edges', () => {
      const nodes = [{ id: 'a', label: 'A', row: 0, col: 0 }];
      
      const result = renderFlowchart(ctx, 0, 0, nodes, []);
      
      expect(result.width).toBeGreaterThan(0);
    });
    
    it('should draw bezier curves for edges', () => {
      const nodes = [
        { id: 'a', label: 'A', row: 0, col: 0 },
        { id: 'b', label: 'B', row: 1, col: 0 }
      ];
      const edges = [{ from: 'a', to: 'b' }];
      
      renderFlowchart(ctx, 0, 0, nodes, edges);
      
      expect(ctx.bezierCurveTo).toHaveBeenCalled();
    });
    
    it('should draw different node shapes', () => {
      const nodes = [
        { id: 'a', label: 'A', row: 0, col: 0, shape: 'rect' },
        { id: 'b', label: 'B', row: 0, col: 1, shape: 'diamond' },
        { id: 'c', label: 'C', row: 0, col: 2, shape: 'circle' }
      ];
      
      renderFlowchart(ctx, 0, 0, nodes, []);
      
      expect(ctx.roundRect).toHaveBeenCalled();
      expect(ctx.ellipse).toHaveBeenCalled();
    });
    
    it('should highlight nodes when specified', () => {
      const nodes = [
        { id: 'a', label: 'A', row: 0, col: 0, highlight: true }
      ];
      
      renderFlowchart(ctx, 0, 0, nodes, []);
      
      // Should use accent color for highlighted nodes
      expect(ctx.fill).toHaveBeenCalled();
    });
    
    it('should use φ-based spacing', () => {
      const nodes = [
        { id: 'a', label: 'A', row: 0, col: 0 },
        { id: 'b', label: 'B', row: 0, col: 1 }
      ];
      
      const result = renderFlowchart(ctx, 0, 0, nodes, [], { nodeW: 100 });
      
      // Gap should be nodeW × φ
      const expectedGap = 100 * PHI;
      expect(result.width).toBeCloseTo(100 + expectedGap, -1);
    });
    
    it('should support LR direction', () => {
      const nodes = [
        { id: 'a', label: 'A', row: 0, col: 0 },
        { id: 'b', label: 'B', row: 1, col: 0 }
      ];
      
      const tbResult = renderFlowchart(ctx, 0, 0, nodes, [], { direction: 'TB' });
      const lrResult = renderFlowchart(ctx, 0, 0, nodes, [], { direction: 'LR' });
      
      // LR should have different dimensions
      expect(tbResult.width).not.toBe(lrResult.width);
    });
  });
  
  describe('renderSequence()', () => {
    it('should render a basic sequence diagram', () => {
      const actors = [
        { id: 'a', name: 'Actor A' },
        { id: 'b', name: 'Actor B' }
      ];
      const messages = [
        { from: 'a', to: 'b', label: 'Message' }
      ];
      
      const result = renderSequence(ctx, 0, 0, actors, messages);
      
      expect(result.width).toBeGreaterThan(0);
      expect(result.height).toBeGreaterThan(0);
    });
    
    it('should throw on invalid actors', () => {
      expect(() => renderSequence(ctx, 0, 0, null, [])).toThrow();
    });
    
    it('should draw lifelines', () => {
      const actors = [{ id: 'a', name: 'A' }];
      
      renderSequence(ctx, 0, 0, actors, []);
      
      expect(ctx.setLineDash).toHaveBeenCalled();
    });
    
    it('should draw message arrows', () => {
      const actors = [
        { id: 'a', name: 'A' },
        { id: 'b', name: 'B' }
      ];
      const messages = [{ from: 'a', to: 'b', label: 'Msg' }];
      
      renderSequence(ctx, 0, 0, actors, messages);
      
      expect(ctx.fill).toHaveBeenCalled();  // Arrow head
    });
    
    it('should handle empty messages', () => {
      const actors = [{ id: 'a', name: 'A' }];
      
      const result = renderSequence(ctx, 0, 0, actors, []);
      
      expect(result.height).toBeGreaterThan(0);
    });
  });
  
  describe('optimalNodeWidth()', () => {
    it('should calculate φ-based node width', () => {
      const width = optimalNodeWidth('Test', 14);
      expect(width).toBeGreaterThan(0);
    });
    
    it('should scale with label length', () => {
      const w1 = optimalNodeWidth('A', 14);
      const w2 = optimalNodeWidth('AAAAAAAAAA', 14);
      expect(w2).toBeGreaterThan(w1);
    });
    
    it('should scale with font size', () => {
      const w1 = optimalNodeWidth('Test', 12);
      const w2 = optimalNodeWidth('Test', 16);
      expect(w2).toBeGreaterThan(w1);
    });
  });
  
  describe('Performance', () => {
    it('should render 500 flowcharts in <300ms', () => {
      const nodes = [
        { id: 'a', label: 'A', row: 0, col: 1 },
        { id: 'b', label: 'B', row: 1, col: 0 },
        { id: 'c', label: 'C', row: 1, col: 2 },
        { id: 'd', label: 'D', row: 2, col: 1 }
      ];
      const edges = [
        { from: 'a', to: 'b' },
        { from: 'a', to: 'c' },
        { from: 'b', to: 'd' },
        { from: 'c', to: 'd' }
      ];
      
      const start = performance.now();
      for (let i = 0; i < 500; i++) {
        renderFlowchart(ctx, 0, 0, nodes, edges);
      }
      const elapsed = performance.now() - start;
      
      expect(elapsed).toBeLessThan(300);
    });
  });
});
