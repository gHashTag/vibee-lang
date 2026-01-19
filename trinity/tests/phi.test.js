/**
 * TRINITY φ-Constants Tests
 * Validates Golden Ratio mathematics
 */

import { describe, it, expect } from 'vitest';
import {
  PHI, PHI_INV, PHI_SQ, PHI_INV_SQ, PHI_CU, TRINITY, FIB,
  space, font, validateGoldenIdentity, fibonacci, isGoldenRatio,
  btreeBranchingFactor, cuckooLoadFactor, radixBucketRatio
} from '../src/phi.js';

describe('φ Constants', () => {
  it('PHI should be approximately 1.618', () => {
    expect(PHI).toBeCloseTo(1.618033988749895, 10);
  });
  
  it('PHI_INV should be 1/φ', () => {
    expect(PHI_INV).toBeCloseTo(1 / PHI, 10);
  });
  
  it('PHI_SQ should be φ²', () => {
    expect(PHI_SQ).toBeCloseTo(PHI * PHI, 10);
  });
  
  it('PHI_INV_SQ should be 1/φ²', () => {
    expect(PHI_INV_SQ).toBeCloseTo(1 / (PHI * PHI), 10);
  });
  
  it('PHI_CU should be φ³', () => {
    expect(PHI_CU).toBeCloseTo(PHI * PHI * PHI, 10);
  });
  
  it('TRINITY should be 3', () => {
    expect(TRINITY).toBe(3);
  });
});

describe('Golden Identity: φ² + 1/φ² = 3', () => {
  it('should validate the Golden Identity', () => {
    const result = PHI_SQ + PHI_INV_SQ;
    expect(result).toBeCloseTo(3, 10);
  });
  
  it('validateGoldenIdentity() should return true', () => {
    expect(validateGoldenIdentity()).toBe(true);
  });
});

describe('Fibonacci Sequence', () => {
  it('FIB should contain correct values', () => {
    expect(FIB[0]).toBe(1);
    expect(FIB[1]).toBe(1);
    expect(FIB[2]).toBe(2);
    expect(FIB[3]).toBe(3);
    expect(FIB[4]).toBe(5);
    expect(FIB[5]).toBe(8);
    expect(FIB[6]).toBe(13);
    expect(FIB[7]).toBe(21);
    expect(FIB[8]).toBe(34);
    expect(FIB[9]).toBe(55);
    expect(FIB[10]).toBe(89);
    expect(FIB[11]).toBe(144);
    expect(FIB[12]).toBe(233);
  });
  
  it('fibonacci() should return correct values', () => {
    expect(fibonacci(0)).toBe(1);
    expect(fibonacci(5)).toBe(8);
    expect(fibonacci(10)).toBe(89);
    expect(fibonacci(15)).toBe(987);
    expect(fibonacci(20)).toBe(10946);
  });
  
  it('consecutive Fibonacci ratios should approach φ', () => {
    for (let i = 10; i < FIB.length; i++) {
      const ratio = FIB[i] / FIB[i - 1];
      expect(ratio).toBeCloseTo(PHI, 2);
    }
  });
});

describe('φ-based Spacing', () => {
  it('space(0) should return 8', () => {
    expect(space(0)).toBe(8);
  });
  
  it('space(1) should return ~13 (8 × φ)', () => {
    expect(space(1)).toBe(13);
  });
  
  it('space(2) should return ~21 (8 × φ²)', () => {
    expect(space(2)).toBe(21);
  });
  
  it('space(3) should return ~34 (8 × φ³)', () => {
    expect(space(3)).toBe(34);
  });
  
  it('spacing should follow Fibonacci pattern', () => {
    const spaces = [space(0), space(1), space(2), space(3), space(4)];
    expect(spaces).toEqual([8, 13, 21, 34, 55]);
  });
});

describe('φ-based Font Scaling', () => {
  it('font(16, 0) should return 16', () => {
    expect(font(16, 0)).toBe(16);
  });
  
  it('font(16, 1) should return ~26 (16 × φ)', () => {
    expect(font(16, 1)).toBe(26);
  });
  
  it('font(16, 2) should return ~42 (16 × φ²)', () => {
    expect(font(16, 2)).toBe(42);
  });
  
  it('font scaling should maintain φ ratio', () => {
    const base = 16;
    const f1 = font(base, 1);
    const f2 = font(base, 2);
    expect(f2 / f1).toBeCloseTo(PHI, 1);
  });
});

describe('Golden Ratio Detection', () => {
  it('isGoldenRatio(1, φ) should return true', () => {
    expect(isGoldenRatio(1, PHI)).toBe(true);
  });
  
  it('isGoldenRatio(8, 13) should return true (Fibonacci)', () => {
    expect(isGoldenRatio(8, 13)).toBe(true);
  });
  
  it('isGoldenRatio(55, 89) should return true (Fibonacci)', () => {
    expect(isGoldenRatio(55, 89)).toBe(true);
  });
  
  it('isGoldenRatio(1, 2) should return false', () => {
    expect(isGoldenRatio(1, 2)).toBe(false);
  });
  
  it('isGoldenRatio(0, 1) should return false', () => {
    expect(isGoldenRatio(0, 1)).toBe(false);
  });
});

describe('Data Structure Optimizations', () => {
  it('btreeBranchingFactor() should return φ² ≈ 2.618', () => {
    expect(btreeBranchingFactor()).toBeCloseTo(2.618, 2);
  });
  
  it('cuckooLoadFactor() should return ~0.95', () => {
    const loadFactor = cuckooLoadFactor();
    expect(loadFactor).toBeGreaterThan(0.9);
    expect(loadFactor).toBeLessThan(1.0);
  });
  
  it('radixBucketRatio() should return φ-based ratios', () => {
    const ratios = radixBucketRatio();
    expect(ratios.primary).toBeCloseTo(PHI_INV, 5);
    expect(ratios.secondary).toBeCloseTo(PHI_INV_SQ, 5);
    expect(ratios.primary + ratios.secondary).toBeCloseTo(1, 5);
  });
});

describe('Mathematical Properties', () => {
  it('φ × (1/φ) = 1', () => {
    expect(PHI * PHI_INV).toBeCloseTo(1, 10);
  });
  
  it('φ² - φ - 1 = 0 (defining equation)', () => {
    expect(PHI_SQ - PHI - 1).toBeCloseTo(0, 10);
  });
  
  it('φ = 1 + 1/φ', () => {
    expect(PHI).toBeCloseTo(1 + PHI_INV, 10);
  });
  
  it('φ² = φ + 1', () => {
    expect(PHI_SQ).toBeCloseTo(PHI + 1, 10);
  });
  
  it('1/φ = φ - 1', () => {
    expect(PHI_INV).toBeCloseTo(PHI - 1, 10);
  });
});
