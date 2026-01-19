// TRINITY φ-Constants Module
// Golden Ratio mathematics for Gleam
//
// φ² + 1/φ² = 3

import gleam/float
import gleam/int
import gleam/list

/// Golden Ratio φ = (1 + √5) / 2
pub const phi: Float = 1.618033988749895

/// Inverse of φ = 1/φ = φ - 1
pub const phi_inv: Float = 0.618033988749895

/// φ squared = φ² = φ + 1
pub const phi_sq: Float = 2.618033988749895

/// Inverse of φ squared = 1/φ²
pub const phi_inv_sq: Float = 0.381966011250105

/// TRINITY constant = φ² + 1/φ² = 3
pub const trinity: Float = 3.0

/// Fibonacci sequence (first 15 numbers)
pub const fib: List(Int) = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610]

/// Validate Golden Identity: φ² + 1/φ² = 3
pub fn validate_golden_identity() -> Bool {
  let result = phi_sq +. phi_inv_sq
  float.absolute_value(result -. trinity) <. 0.0000000001
}

/// Calculate φ-based spacing
pub fn space(n: Int) -> Int {
  let base = 8.0
  let exp = int.to_float(n)
  float.round(base *. float.power(phi, exp))
}

/// Calculate φ-based font size
pub fn font(base: Int, level: Int) -> Int {
  let base_f = int.to_float(base)
  let level_f = int.to_float(level)
  float.round(base_f *. float.power(phi, level_f))
}

/// Get Fibonacci number at index
pub fn fibonacci(n: Int) -> Int {
  case n {
    0 -> 1
    1 -> 1
    _ -> fibonacci_iter(n, 1, 1, 2)
  }
}

fn fibonacci_iter(target: Int, a: Int, b: Int, current: Int) -> Int {
  case current > target {
    True -> b
    False -> fibonacci_iter(target, b, a + b, current + 1)
  }
}

/// Check if ratio approximates φ
pub fn is_golden_ratio(a: Float, b: Float) -> Bool {
  case a <=. 0.0 || b <=. 0.0 {
    True -> False
    False -> {
      let ratio = b /. a
      float.absolute_value(ratio -. phi) <. 0.01
    }
  }
}

/// Calculate φ-optimized B-Tree branching factor
pub fn btree_branching_factor() -> Float {
  phi_sq
}

/// Calculate φ-optimized Cuckoo Hash load factor
pub fn cuckoo_load_factor() -> Float {
  1.0 -. phi_inv_sq /. 8.0
}

/// Calculate φ-optimized Radix Sort bucket ratios
pub fn radix_bucket_ratio() -> #(Float, Float) {
  #(phi_inv, phi_inv_sq)
}

/// Calculate bezier point at t
pub fn bezier_point(p0: Float, p1: Float, p2: Float, p3: Float, t: Float) -> Float {
  let t2 = t *. t
  let t3 = t2 *. t
  let mt = 1.0 -. t
  let mt2 = mt *. mt
  let mt3 = mt2 *. mt
  
  mt3 *. p0 +. 3.0 *. mt2 *. t *. p1 +. 3.0 *. mt *. t2 *. p2 +. t3 *. p3
}

/// Calculate φ-optimized bezier control point
pub fn phi_bezier_control(start: Float, end: Float) -> Float {
  start +. { end -. start } *. phi_inv
}
