/**
 * TRINITY φ-Constants Module
 * Golden Ratio mathematics for data structure optimization
 * 
 * φ² + 1/φ² = 3 (Golden Identity)
 */

export const PHI = 1.618033988749895;
export const PHI_INV = 0.618033988749895;      // 1/φ
export const PHI_SQ = 2.618033988749895;       // φ²
export const PHI_INV_SQ = 0.381966011250105;   // 1/φ²
export const PHI_CU = 4.236067977499790;       // φ³
export const TRINITY = 3;                       // φ² + 1/φ²

// Fibonacci sequence (precomputed)
export const FIB = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610];

/**
 * Calculate φ-based spacing
 * @param {number} n - Scale level
 * @returns {number} Spacing value
 */
export function space(n) {
  return Math.round(8 * Math.pow(PHI, n));
}

/**
 * Calculate φ-based font size
 * @param {number} base - Base font size
 * @param {number} level - Scale level
 * @returns {number} Font size
 */
export function font(base, level) {
  return Math.round(base * Math.pow(PHI, level));
}

/**
 * Validate Golden Identity: φ² + 1/φ² = 3
 * @returns {boolean} True if identity holds
 */
export function validateGoldenIdentity() {
  const result = PHI_SQ + PHI_INV_SQ;
  return Math.abs(result - TRINITY) < 1e-10;
}

/**
 * Get Fibonacci number at index
 * @param {number} n - Index
 * @returns {number} Fibonacci number
 */
export function fibonacci(n) {
  if (n < FIB.length) return FIB[n];
  
  let a = FIB[FIB.length - 2];
  let b = FIB[FIB.length - 1];
  
  for (let i = FIB.length; i <= n; i++) {
    const temp = a + b;
    a = b;
    b = temp;
  }
  
  return b;
}

/**
 * Check if ratio approximates φ
 * @param {number} a - First number
 * @param {number} b - Second number (larger)
 * @param {number} tolerance - Tolerance (default 0.01)
 * @returns {boolean} True if b/a ≈ φ
 */
export function isGoldenRatio(a, b, tolerance = 0.01) {
  if (a <= 0 || b <= 0) return false;
  const ratio = b / a;
  return Math.abs(ratio - PHI) < tolerance;
}

/**
 * Calculate φ-optimized branching factor for B-Tree
 * @returns {number} Optimal branching factor ≈ 2.618
 */
export function btreeBranchingFactor() {
  return PHI_SQ;
}

/**
 * Calculate φ-optimized load factor for Cuckoo Hash
 * @returns {number} Optimal load factor ≈ 0.951
 */
export function cuckooLoadFactor() {
  return 1 - PHI_INV_SQ / 8;  // ≈ 0.952
}

/**
 * Calculate φ-optimized bucket ratio for Radix Sort
 * @returns {object} Bucket ratios
 */
export function radixBucketRatio() {
  return {
    primary: PHI_INV,      // 0.618
    secondary: PHI_INV_SQ  // 0.382
  };
}
