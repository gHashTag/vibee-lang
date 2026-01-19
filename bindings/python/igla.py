#!/usr/bin/env python3
"""
IGLA Python Bindings
═══════════════════════════════════════════════════════════════════════════════
ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
PHOENIX = 999 = 3³ × 37
═══════════════════════════════════════════════════════════════════════════════
"""

import ctypes
import os
from pathlib import Path
from typing import List, Tuple

# Sacred Constants
PHI = 1.618033988749895
TRINITY = 3
PHOENIX = 999
SPEED_OF_LIGHT = 299792458

class TriParseResult(ctypes.Structure):
    """Result of TRI parsing"""
    _fields_ = [
        ("entries", ctypes.c_int64),
        ("keys", ctypes.c_int64),
        ("values", ctypes.c_int64),
        ("bytes_parsed", ctypes.c_int64),
        ("success", ctypes.c_int32),
    ]

class IGLA:
    """IGLA Library Python Interface"""
    
    def __init__(self, lib_path: str = None):
        """Initialize IGLA library
        
        Args:
            lib_path: Path to libigla.so/dylib. If None, searches in standard locations.
        """
        if lib_path is None:
            # Try to find the library
            search_paths = [
                Path(__file__).parent / "libigla.so",
                Path(__file__).parent / "libigla.dylib",
                Path(__file__).parent.parent.parent / "zig-out" / "lib" / "libigla.so",
                Path(__file__).parent.parent.parent / "zig-out" / "lib" / "libigla.dylib",
            ]
            
            for path in search_paths:
                if path.exists():
                    lib_path = str(path)
                    break
            
            if lib_path is None:
                raise FileNotFoundError(
                    "Could not find libigla. Build with: "
                    "zig build-lib bindings/python/igla_lib.zig -dynamic -O ReleaseFast"
                )
        
        self._lib = ctypes.CDLL(lib_path)
        self._setup_functions()
    
    def _setup_functions(self):
        """Setup function signatures"""
        # Version
        self._lib.igla_version_major.restype = ctypes.c_int32
        self._lib.igla_version_minor.restype = ctypes.c_int32
        self._lib.igla_version_patch.restype = ctypes.c_int32
        
        # TRI Parser
        self._lib.igla_tri_parse.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
        self._lib.igla_tri_parse.restype = TriParseResult
        
        # Math functions
        self._lib.igla_fibonacci.argtypes = [ctypes.c_int64]
        self._lib.igla_fibonacci.restype = ctypes.c_int64
        
        self._lib.igla_factorial.argtypes = [ctypes.c_int64]
        self._lib.igla_factorial.restype = ctypes.c_int64
        
        self._lib.igla_sum_to_n.argtypes = [ctypes.c_int64]
        self._lib.igla_sum_to_n.restype = ctypes.c_int64
        
        self._lib.igla_is_prime.argtypes = [ctypes.c_int64]
        self._lib.igla_is_prime.restype = ctypes.c_int32
        
        # Golden ratio
        self._lib.igla_golden_identity.restype = ctypes.c_double
        
        self._lib.igla_phi_power.argtypes = [ctypes.c_int32]
        self._lib.igla_phi_power.restype = ctypes.c_double
        
        # Array operations
        self._lib.igla_array_sum.argtypes = [ctypes.POINTER(ctypes.c_int64), ctypes.c_size_t]
        self._lib.igla_array_sum.restype = ctypes.c_int64
        
        self._lib.igla_array_max.argtypes = [ctypes.POINTER(ctypes.c_int64), ctypes.c_size_t]
        self._lib.igla_array_max.restype = ctypes.c_int64
        
        self._lib.igla_array_min.argtypes = [ctypes.POINTER(ctypes.c_int64), ctypes.c_size_t]
        self._lib.igla_array_min.restype = ctypes.c_int64
        
        self._lib.igla_dot_product.argtypes = [
            ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double),
            ctypes.c_size_t
        ]
        self._lib.igla_dot_product.restype = ctypes.c_double
    
    @property
    def version(self) -> Tuple[int, int, int]:
        """Get IGLA version"""
        return (
            self._lib.igla_version_major(),
            self._lib.igla_version_minor(),
            self._lib.igla_version_patch(),
        )
    
    def parse_tri(self, source: str) -> dict:
        """Parse TRI document
        
        Args:
            source: TRI document as string
            
        Returns:
            dict with entries, keys, values, bytes_parsed, success
        """
        data = source.encode('utf-8')
        result = self._lib.igla_tri_parse(data, len(data))
        return {
            'entries': result.entries,
            'keys': result.keys,
            'values': result.values,
            'bytes_parsed': result.bytes_parsed,
            'success': bool(result.success),
        }
    
    def fibonacci(self, n: int) -> int:
        """Calculate Fibonacci number"""
        return self._lib.igla_fibonacci(n)
    
    def factorial(self, n: int) -> int:
        """Calculate factorial"""
        return self._lib.igla_factorial(n)
    
    def sum_to_n(self, n: int) -> int:
        """Calculate sum from 1 to n"""
        return self._lib.igla_sum_to_n(n)
    
    def is_prime(self, n: int) -> bool:
        """Check if number is prime"""
        return bool(self._lib.igla_is_prime(n))
    
    def golden_identity(self) -> float:
        """Calculate φ² + 1/φ² (should equal 3)"""
        return self._lib.igla_golden_identity()
    
    def phi_power(self, n: int) -> float:
        """Calculate φ^n"""
        return self._lib.igla_phi_power(n)
    
    def array_sum(self, arr: List[int]) -> int:
        """Sum array elements"""
        c_arr = (ctypes.c_int64 * len(arr))(*arr)
        return self._lib.igla_array_sum(c_arr, len(arr))
    
    def array_max(self, arr: List[int]) -> int:
        """Find maximum in array"""
        c_arr = (ctypes.c_int64 * len(arr))(*arr)
        return self._lib.igla_array_max(c_arr, len(arr))
    
    def array_min(self, arr: List[int]) -> int:
        """Find minimum in array"""
        c_arr = (ctypes.c_int64 * len(arr))(*arr)
        return self._lib.igla_array_min(c_arr, len(arr))
    
    def dot_product(self, a: List[float], b: List[float]) -> float:
        """Calculate dot product of two vectors"""
        if len(a) != len(b):
            raise ValueError("Vectors must have same length")
        c_a = (ctypes.c_double * len(a))(*a)
        c_b = (ctypes.c_double * len(b))(*b)
        return self._lib.igla_dot_product(c_a, c_b, len(a))


# Pure Python implementations for comparison
def py_fibonacci(n: int) -> int:
    """Pure Python Fibonacci"""
    if n <= 1:
        return n
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b


def py_is_prime(n: int) -> bool:
    """Pure Python primality test"""
    if n <= 1:
        return False
    if n <= 3:
        return True
    if n % 2 == 0 or n % 3 == 0:
        return False
    i = 5
    while i * i <= n:
        if n % i == 0 or n % (i + 2) == 0:
            return False
        i += 6
    return True


def benchmark():
    """Run benchmark comparing IGLA vs pure Python"""
    import time
    
    print()
    print("═" * 79)
    print("  IGLA PYTHON BENCHMARK")
    print("  ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q")
    print(f"  PHOENIX = {PHOENIX} = 3³ × 37")
    print("═" * 79)
    print()
    
    try:
        igla = IGLA()
        print(f"IGLA version: {igla.version[0]}.{igla.version[1]}.{igla.version[2]}")
        print()
    except FileNotFoundError as e:
        print(f"Error: {e}")
        print("Running pure Python benchmarks only...")
        igla = None
    
    iterations = 100000
    
    # Fibonacci benchmark
    print(f"Benchmark: Fibonacci(30) x {iterations}")
    
    # Python
    start = time.perf_counter()
    for _ in range(iterations):
        py_fibonacci(30)
    py_time = time.perf_counter() - start
    print(f"  Python: {py_time * 1000:.2f} ms")
    
    if igla:
        # IGLA
        start = time.perf_counter()
        for _ in range(iterations):
            igla.fibonacci(30)
        igla_time = time.perf_counter() - start
        print(f"  IGLA:   {igla_time * 1000:.2f} ms")
        print(f"  Speedup: {py_time / igla_time:.1f}x")
    
    print()
    
    # Prime check benchmark
    print(f"Benchmark: is_prime(999983) x {iterations}")
    
    # Python
    start = time.perf_counter()
    for _ in range(iterations):
        py_is_prime(999983)
    py_time = time.perf_counter() - start
    print(f"  Python: {py_time * 1000:.2f} ms")
    
    if igla:
        # IGLA
        start = time.perf_counter()
        for _ in range(iterations):
            igla.is_prime(999983)
        igla_time = time.perf_counter() - start
        print(f"  IGLA:   {igla_time * 1000:.2f} ms")
        print(f"  Speedup: {py_time / igla_time:.1f}x")
    
    print()
    
    # Golden identity
    if igla:
        print("Golden Identity Test:")
        result = igla.golden_identity()
        print(f"  φ² + 1/φ² = {result:.10f}")
        print(f"  Expected:  3.0000000000")
        print(f"  ✅ Correct!" if abs(result - 3.0) < 0.0001 else "  ❌ Error!")
    
    print()
    print("═" * 79)
    print("  🔥 PHOENIX BLESSING: Benchmark complete!")
    print("═" * 79)


if __name__ == "__main__":
    benchmark()
