'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { Link } from 'react-router-dom';

// === CONFIGURATION ===
const LANGUAGES = [
  { id: 'vibee', name: 'VIBEE (.999)', ext: '.999', icon: '🔺', color: '#00E599' },
  { id: 'python', name: 'Python', ext: '.py', icon: '🐍', color: '#3776AB' },
  { id: 'rust', name: 'Rust', ext: '.rs', icon: '🦀', color: '#CE422B' },
  { id: 'zig', name: 'Zig', ext: '.zig', icon: '⚡', color: '#F7A41D' },
  { id: 'cpp', name: 'C++', ext: '.cpp', icon: '⚙️', color: '#00599C' },
];

const TARGETS = [
  { id: 'verilog', name: 'Verilog', ext: '.v', icon: '📟', color: '#00ACC1' },
  { id: 'systemverilog', name: 'SystemVerilog', ext: '.sv', icon: 'SV', color: '#7B1FA2' },
  { id: 'vhdl', name: 'VHDL', ext: '.vhd', icon: '📼', color: '#388E3C' },
  { id: 'zig', name: 'Zig (IR)', ext: '.zig', icon: '⚡', color: '#F7A41D' },
];

// === SAMPLE CODE ===
const SAMPLES: Record<string, string> = {
  vibee: `// TRINITY NATIVE - Hardware Acceleration
// Target: Trinity Core V5.0 (SU(3) Quantum-Optical)

module quantum_kernel {
    const PHI = 1.6180339887;
    const TRINITY = 27;
    
    // Ternary state: -1, 0, +1
    type Trit = tryte;
    
    pub fn golden_transform(x: i64) -> i64 {
        // Hardware-accelerated on Trinity NPU
        return x * PHI + x / PHI;
    }
    
    pub fn tensor_product(a: mat3, b: mat3) -> mat9 {
        // Native SU(3) operation - 1 cycle
        return a ⊗ b;
    }
    
    pub fn main() {
        let result = golden_transform(TRINITY);
        print("φ² + 1/φ² = ", result);
    }
}`,
  python: `# Python → Hardware Acceleration
# Trinity HLS Compiler Demo

import trinity

@trinity.accelerate(target="verilog")
def matrix_multiply(A, B):
    """Hardware-accelerated matrix multiply"""
    n = len(A)
    C = [[0] * n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            for k in range(n):
                C[i][j] += A[i][k] * B[k][j]
    return C

@trinity.kernel
def fft_butterfly(x, y, twiddle):
    """FFT butterfly operation"""
    t = y * twiddle
    return x + t, x - t

if __name__ == "__main__":
    result = matrix_multiply([[1,2],[3,4]], [[5,6],[7,8]])
    print(f"Result: {result}")`,
  rust: `// Rust → Hardware Synthesis
// Trinity HLS Compiler Demo

#[trinity::accelerate]
fn fibonacci_hw(n: u32) -> u64 {
    // Synthesized to parallel hardware
    if n <= 1 {
        return n as u64;
    }
    
    let mut a: u64 = 0;
    let mut b: u64 = 1;
    
    for _ in 2..=n {
        let temp = a + b;
        a = b;
        b = temp;
    }
    
    b
}

#[trinity::kernel]
fn vector_add(a: &[i32], b: &[i32]) -> Vec<i32> {
    // Parallel SIMD execution on FPGA
    a.iter().zip(b.iter()).map(|(x, y)| x + y).collect()
}

fn main() {
    let result = fibonacci_hw(42);
    println!("Fib(42) = {}", result);
}`,
  zig: `// Zig → Trinity Native Compilation
// Direct mapping to SU(3) hardware

const std = @import("std");
const trinity = @import("trinity");

// Compile-time constant - baked into hardware
const PHI: f64 = 1.6180339887498948;

pub fn goldenRatio(x: f64) callconv(.Trinity) f64 {
    // Native Trinity instruction: TRI_PHI_MUL
    return x * PHI + x / PHI;
}

pub fn ternaryAdd(a: i3, b: i3) callconv(.Trinity) i3 {
    // Ternary arithmetic - no binary conversion
    return @truncate(a + b);
}

pub fn main() !void {
    const result = goldenRatio(27.0);
    std.debug.print("φ² + 1/φ² = {d:.6}\\n", .{result});
}`,
  cpp: `// C++ → Hardware Synthesis
// Trinity HLS Compiler Demo

#include <trinity/hls.hpp>
#include <array>

// Pragma: synthesize to parallel hardware
#pragma trinity accelerate
template<size_t N>
std::array<int, N> parallel_prefix_sum(const std::array<int, N>& input) {
    std::array<int, N> output;
    output[0] = input[0];
    
    // Automatically pipelined on FPGA
    for (size_t i = 1; i < N; ++i) {
        output[i] = output[i-1] + input[i];
    }
    
    return output;
}

#pragma trinity kernel
void matrix_transpose(int A[8][8], int B[8][8]) {
    // Parallel memory access pattern
    for (int i = 0; i < 8; ++i) {
        for (int j = 0; j < 8; ++j) {
            B[j][i] = A[i][j];
        }
    }
}

int main() {
    std::array<int, 8> data = {1, 2, 3, 4, 5, 6, 7, 8};
    auto result = parallel_prefix_sum(data);
    return 0;
}`,
};

// === SIMULATED COMPILER OUTPUT ===
function generateOutput(source: string, sourceLang: string, targetLang: string): { code: string; logs: string[] } {
  const timestamp = new Date().toISOString();
  const lines = source.split('\n').length;
  const chars = source.length;
  
  const logs: string[] = [
    `[${timestamp}] Trinity HLS Compiler V5.0`,
    `[INFO] Source: ${sourceLang.toUpperCase()} (${lines} lines, ${chars} chars)`,
    `[INFO] Target: ${targetLang.toUpperCase()}`,
    `[PASS] Lexical analysis... OK`,
    `[PASS] Parsing AST... ${Math.floor(lines * 1.5)} nodes`,
    `[PASS] Semantic analysis... OK`,
    `[PASS] SU(3) optimization... 12 patterns applied`,
    `[PASS] Golden ratio scheduling (φ = 1.618)`,
    `[PASS] Resource allocation: 3 DSPs, 12 BRAMs`,
    `[PASS] Generating ${targetLang}...`,
    `[SUCCESS] Compilation complete (0.042s)`,
  ];
  
  let code = '';
  
  if (targetLang === 'verilog') {
    code = `// ============================================================
// TRINITY HLS COMPILER V5.0 - GENERATED VERILOG
// ============================================================
// Source: ${sourceLang} | Generated: ${timestamp}
// Optimization: MAXIMUM (SU(3) Native)
// Clock: 250 MHz | Latency: 3 cycles | Throughput: 1 op/cycle
// ============================================================

\`timescale 1ns / 1ps

module trinity_accelerator #(
    parameter DATA_WIDTH = 32,
    parameter TRIT_WIDTH = 3     // Ternary: -1, 0, +1
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     valid_in,
    input  wire [DATA_WIDTH-1:0]    data_in,
    input  wire [TRIT_WIDTH-1:0]    trit_in,
    output reg                      valid_out,
    output reg  [DATA_WIDTH-1:0]    data_out,
    output reg  [TRIT_WIDTH-1:0]    trit_out
);

    // ═══════════════════════════════════════════════════════════
    // SACRED CONSTANTS (φ = 1.618033988749895)
    // ═══════════════════════════════════════════════════════════
    localparam [31:0] PHI_FIXED = 32'h19E3779B;  // φ in Q16.16
    localparam [31:0] PHI_INV   = 32'h09E3779B;  // 1/φ in Q16.16
    
    // ═══════════════════════════════════════════════════════════
    // PIPELINE REGISTERS
    // ═══════════════════════════════════════════════════════════
    reg [DATA_WIDTH-1:0] stage1_data;
    reg [DATA_WIDTH-1:0] stage2_data;
    reg [2:0] valid_pipe;
    
    // ═══════════════════════════════════════════════════════════
    // STAGE 1: Golden Ratio Multiply (x * φ)
    // ═══════════════════════════════════════════════════════════
    wire [63:0] phi_product = data_in * PHI_FIXED;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_data <= 0;
            valid_pipe[0] <= 0;
        end else begin
            stage1_data <= phi_product[47:16];  // Q16.16 result
            valid_pipe[0] <= valid_in;
        end
    end
    
    // ═══════════════════════════════════════════════════════════
    // STAGE 2: Inverse Add (x + x/φ)
    // ═══════════════════════════════════════════════════════════
    wire [63:0] phi_inv_product = data_in * PHI_INV;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage2_data <= 0;
            valid_pipe[1] <= 0;
        end else begin
            stage2_data <= stage1_data + phi_inv_product[47:16];
            valid_pipe[1] <= valid_pipe[0];
        end
    end
    
    // ═══════════════════════════════════════════════════════════
    // STAGE 3: Ternary Logic (SU(3) Native)
    // ═══════════════════════════════════════════════════════════
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 0;
            trit_out <= 3'b000;
            valid_out <= 0;
            valid_pipe[2] <= 0;
        end else begin
            data_out <= stage2_data;
            
            // Ternary state machine: |0⟩ → |1⟩ → |2⟩ → |0⟩
            case (trit_in)
                3'b000: trit_out <= 3'b001;  // |0⟩ → |1⟩
                3'b001: trit_out <= 3'b010;  // |1⟩ → |2⟩
                3'b010: trit_out <= 3'b000;  // |2⟩ → |0⟩
                default: trit_out <= 3'bxxx;
            endcase
            
            valid_pipe[2] <= valid_pipe[1];
            valid_out <= valid_pipe[2];
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════
// TESTBENCH (Auto-generated)
// ═══════════════════════════════════════════════════════════════
\`ifdef TESTBENCH
module tb_trinity_accelerator;
    reg clk = 0;
    always #2 clk = ~clk;  // 250 MHz
    
    reg rst_n = 0;
    reg valid_in = 0;
    reg [31:0] data_in = 0;
    wire valid_out;
    wire [31:0] data_out;
    
    trinity_accelerator dut (.*);
    
    initial begin
        #10 rst_n = 1;
        #10 valid_in = 1; data_in = 32'd27;  // TRINITY constant
        #4  valid_in = 0;
        #20 $display("Result: %d (expected: golden transform of 27)", data_out);
        #10 $finish;
    end
endmodule
\`endif`;
  } else if (targetLang === 'systemverilog') {
    code = `// ============================================================
// TRINITY HLS COMPILER V5.0 - GENERATED SYSTEMVERILOG
// ============================================================
// Source: ${sourceLang} | Generated: ${timestamp}
// Optimization: MAXIMUM (SU(3) Native)
// ============================================================

module trinity_accelerator #(
    parameter int DATA_WIDTH = 32,
    parameter int TRIT_WIDTH = 3
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     valid_in,
    input  logic [DATA_WIDTH-1:0]    data_in,
    output logic                     valid_out,
    output logic [DATA_WIDTH-1:0]    data_out
);

    // Sacred constants
    localparam real PHI = 1.6180339887498948;
    localparam logic [31:0] PHI_FIXED = 32'h19E3779B;
    
    // Pipeline stages with SV interfaces
    typedef struct packed {
        logic valid;
        logic [DATA_WIDTH-1:0] data;
    } pipeline_t;
    
    pipeline_t stage [0:2];
    
    // Golden ratio transformation
    function automatic logic [DATA_WIDTH-1:0] golden_transform(
        input logic [DATA_WIDTH-1:0] x
    );
        logic [63:0] product = x * PHI_FIXED;
        return product[47:16];
    endfunction
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            foreach (stage[i]) stage[i] <= '0;
            valid_out <= 0;
            data_out <= 0;
        end else begin
            // Stage 0: Input
            stage[0].valid <= valid_in;
            stage[0].data <= data_in;
            
            // Stage 1: Transform
            stage[1].valid <= stage[0].valid;
            stage[1].data <= golden_transform(stage[0].data);
            
            // Stage 2: Output
            stage[2] <= stage[1];
            valid_out <= stage[2].valid;
            data_out <= stage[2].data;
        end
    end
    
    // Assertions for verification
    \`ifdef FORMAL
    property valid_propagation;
        @(posedge clk) disable iff (!rst_n)
        valid_in |-> ##3 valid_out;
    endproperty
    
    assert property (valid_propagation);
    \`endif

endmodule`;
  } else if (targetLang === 'vhdl') {
    code = `-- ============================================================
-- TRINITY HLS COMPILER V5.0 - GENERATED VHDL
-- ============================================================
-- Source: ${sourceLang} | Generated: ${timestamp}
-- Optimization: MAXIMUM (SU(3) Native)
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity trinity_accelerator is
    generic (
        DATA_WIDTH : integer := 32;
        TRIT_WIDTH : integer := 3
    );
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        valid_in  : in  std_logic;
        data_in   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_out : out std_logic;
        data_out  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity trinity_accelerator;

architecture RTL of trinity_accelerator is
    -- Sacred Constants (φ = 1.618033988749895)
    constant PHI_FIXED : unsigned(31 downto 0) := x"19E3779B";
    
    -- Pipeline registers
    signal stage1_data : unsigned(DATA_WIDTH-1 downto 0);
    signal stage2_data : unsigned(DATA_WIDTH-1 downto 0);
    signal valid_pipe  : std_logic_vector(2 downto 0);
    
begin
    -- Golden Ratio Transformation Pipeline
    process(clk, rst_n)
        variable phi_product : unsigned(63 downto 0);
    begin
        if rst_n = '0' then
            stage1_data <= (others => '0');
            stage2_data <= (others => '0');
            valid_pipe  <= (others => '0');
            valid_out   <= '0';
            data_out    <= (others => '0');
        elsif rising_edge(clk) then
            -- Stage 1: Multiply by φ
            phi_product := unsigned(data_in) * PHI_FIXED;
            stage1_data <= phi_product(47 downto 16);
            valid_pipe(0) <= valid_in;
            
            -- Stage 2: Accumulate
            stage2_data <= stage1_data;
            valid_pipe(1) <= valid_pipe(0);
            
            -- Stage 3: Output
            data_out <= std_logic_vector(stage2_data);
            valid_pipe(2) <= valid_pipe(1);
            valid_out <= valid_pipe(2);
        end if;
    end process;

end architecture RTL;`;
  } else {
    code = `// ============================================================
// TRINITY HLS COMPILER V5.0 - GENERATED ZIG IR
// ============================================================
// Source: ${sourceLang} | Generated: ${timestamp}
// ============================================================

const std = @import("std");
const trinity = @import("trinity_runtime");

pub const PHI: f64 = 1.6180339887498948;
pub const TRINITY: u32 = 27;

/// Hardware-accelerated golden ratio transform
pub fn goldenTransform(x: f64) callconv(.Trinity) f64 {
    return @mulAdd(f64, x, PHI, x / PHI);
}

/// Ternary logic operation (SU(3) native)
pub fn ternaryRotate(trit: i3) callconv(.Trinity) i3 {
    return switch (trit) {
        -1 => 0,
        0 => 1,
        1 => -1,
        else => unreachable,
    };
}

/// Main entry point
pub fn main() !void {
    const result = goldenTransform(@floatFromInt(TRINITY));
    std.debug.print("φ² + 1/φ² = {d:.15}\\n", .{result});
}

// === HARDWARE SYNTHESIS METADATA ===
// Latency: 3 cycles
// Throughput: 1 op/cycle  
// Resources: 3 DSPs, 12 BRAMs, 450 LUTs
// Target: Trinity Core V5.0 (SU(3))`;
  }
  
  return { code, logs };
}

// === STYLES ===
const styles = {
  container: {
    display: 'flex',
    flexDirection: 'column' as const,
    height: '100vh',
    background: '#0d1117',
    color: '#c9d1d9',
    fontFamily: "'JetBrains Mono', 'Fira Code', 'SF Mono', Consolas, monospace",
    overflow: 'hidden',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '0 16px',
    height: '48px',
    background: '#161b22',
    borderBottom: '1px solid #30363d',
    flexShrink: 0,
  },
  logo: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    textDecoration: 'none',
  },
  logoIcon: {
    fontSize: '24px',
  },
  logoText: {
    fontSize: '16px',
    fontWeight: 700,
    color: '#fff',
    letterSpacing: '-0.5px',
  },
  badge: {
    fontSize: '10px',
    fontWeight: 600,
    color: '#8b949e',
    background: '#21262d',
    padding: '2px 6px',
    borderRadius: '3px',
    border: '1px solid #30363d',
    marginLeft: '8px',
  },
  headerActions: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  runButton: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    background: '#238636',
    color: '#fff',
    border: 'none',
    borderRadius: '6px',
    padding: '6px 14px',
    fontSize: '13px',
    fontWeight: 600,
    cursor: 'pointer',
    transition: 'background 0.15s',
  },
  headerButton: {
    background: 'transparent',
    color: '#8b949e',
    border: '1px solid #30363d',
    borderRadius: '6px',
    padding: '5px 12px',
    fontSize: '12px',
    cursor: 'pointer',
    transition: 'all 0.15s',
  },
  main: {
    display: 'flex',
    flex: 1,
    overflow: 'hidden',
  },
  pane: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column' as const,
    minWidth: 0,
  },
  paneHeader: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '8px 16px',
    background: '#161b22',
    borderBottom: '1px solid #30363d',
    flexShrink: 0,
    height: '40px',
  },
  paneTitle: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  paneTitleText: {
    fontSize: '12px',
    fontWeight: 600,
    color: '#8b949e',
    textTransform: 'uppercase' as const,
    letterSpacing: '0.5px',
  },
  select: {
    background: '#21262d',
    color: '#c9d1d9',
    border: '1px solid #30363d',
    borderRadius: '6px',
    padding: '4px 8px',
    fontSize: '12px',
    fontWeight: 500,
    cursor: 'pointer',
    outline: 'none',
  },
  editorContainer: {
    flex: 1,
    position: 'relative' as const,
    overflow: 'hidden',
  },
  textarea: {
    position: 'absolute' as const,
    inset: 0,
    width: '100%',
    height: '100%',
    background: '#0d1117',
    color: '#c9d1d9',
    border: 'none',
    outline: 'none',
    resize: 'none' as const,
    padding: '16px',
    fontSize: '13px',
    lineHeight: '1.6',
    fontFamily: 'inherit',
    tabSize: 4,
  },
  outputTextarea: {
    position: 'absolute' as const,
    inset: 0,
    width: '100%',
    height: '100%',
    background: '#0d1117',
    color: '#7ee787',
    border: 'none',
    outline: 'none',
    resize: 'none' as const,
    padding: '16px',
    fontSize: '13px',
    lineHeight: '1.6',
    fontFamily: 'inherit',
    tabSize: 4,
  },
  divider: {
    width: '1px',
    background: '#30363d',
    cursor: 'col-resize',
    transition: 'background 0.15s',
  },
  tabs: {
    display: 'flex',
    gap: '0',
    background: '#21262d',
    borderRadius: '6px',
    padding: '2px',
  },
  tab: {
    padding: '4px 12px',
    fontSize: '11px',
    fontWeight: 500,
    color: '#8b949e',
    background: 'transparent',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    transition: 'all 0.15s',
  },
  tabActive: {
    padding: '4px 12px',
    fontSize: '11px',
    fontWeight: 500,
    color: '#c9d1d9',
    background: '#0d1117',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    boxShadow: '0 1px 2px rgba(0,0,0,0.3)',
  },
  logsContainer: {
    position: 'absolute' as const,
    inset: 0,
    overflow: 'auto',
    padding: '12px 16px',
    fontSize: '12px',
    lineHeight: '1.8',
  },
  logLine: {
    fontFamily: 'inherit',
    whiteSpace: 'pre' as const,
  },
  footer: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '0 16px',
    height: '24px',
    background: '#58a6ff',
    color: '#0d1117',
    fontSize: '11px',
    fontWeight: 500,
    flexShrink: 0,
  },
  loadingOverlay: {
    position: 'absolute' as const,
    inset: 0,
    display: 'flex',
    flexDirection: 'column' as const,
    alignItems: 'center',
    justifyContent: 'center',
    background: 'rgba(13, 17, 23, 0.9)',
    gap: '16px',
  },
  spinner: {
    width: '32px',
    height: '32px',
    border: '3px solid #30363d',
    borderTopColor: '#58a6ff',
    borderRadius: '50%',
    animation: 'spin 0.8s linear infinite',
  },
};

// === COMPONENT ===
export default function Playground() {
  const [sourceLang, setSourceLang] = useState('vibee');
  const [targetLang, setTargetLang] = useState('verilog');
  const [code, setCode] = useState(SAMPLES['vibee']);
  const [output, setOutput] = useState('');
  const [logs, setLogs] = useState<string[]>([]);
  const [activeTab, setActiveTab] = useState<'output' | 'logs'>('output');
  const [isCompiling, setIsCompiling] = useState(false);
  const [compileTime, setCompileTime] = useState<number | null>(null);
  const outputRef = useRef<HTMLTextAreaElement>(null);

  const compile = useCallback(() => {
    setIsCompiling(true);
    setLogs(['[INFO] Starting compilation...']);
    const startTime = performance.now();
    
    // Simulate compilation delay for realism
    setTimeout(() => {
      const result = generateOutput(code, sourceLang, targetLang);
      setOutput(result.code);
      setLogs(result.logs);
      setCompileTime(Math.round(performance.now() - startTime));
      setIsCompiling(false);
      setActiveTab('output');
    }, 300 + Math.random() * 200);
  }, [code, sourceLang, targetLang]);

  useEffect(() => {
    setCode(SAMPLES[sourceLang] || '// Enter code here...');
  }, [sourceLang]);

  useEffect(() => {
    compile();
  }, [targetLang]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      compile();
    }
  };

  const sourceInfo = LANGUAGES.find(l => l.id === sourceLang);
  const targetInfo = TARGETS.find(t => t.id === targetLang);

  return (
    <div style={styles.container}>
      <style>{`
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
        select:hover, button:hover {
          filter: brightness(1.1);
        }
        .divider:hover {
          background: #58a6ff !important;
        }
      `}</style>
      
      {/* Header */}
      <header style={styles.header}>
        <Link to="/" style={styles.logo}>
          <span style={styles.logoIcon}>🔺</span>
          <span style={styles.logoText}>TRINITY</span>
          <span style={styles.badge}>PLAYGROUND</span>
        </Link>
        
        <div style={styles.headerActions}>
          <button 
            style={styles.runButton}
            onClick={compile}
            disabled={isCompiling}
          >
            <span>▶</span> Run {isCompiling ? '' : '⌘↵'}
          </button>
          <button style={styles.headerButton}>Share</button>
          <button style={styles.headerButton}>Examples</button>
          <Link to="/" style={{...styles.headerButton, textDecoration: 'none'}}>
            ← Back
          </Link>
        </div>
      </header>

      {/* Main Editor Area */}
      <main style={styles.main}>
        {/* Left Pane - Source Code */}
        <div style={styles.pane}>
          <div style={styles.paneHeader}>
            <div style={styles.paneTitle}>
              <span style={{color: sourceInfo?.color}}>{sourceInfo?.icon}</span>
              <span style={styles.paneTitleText}>Source</span>
            </div>
            <select 
              style={styles.select}
              value={sourceLang}
              onChange={(e) => setSourceLang(e.target.value)}
            >
              {LANGUAGES.map(l => (
                <option key={l.id} value={l.id}>{l.icon} {l.name}</option>
              ))}
            </select>
          </div>
          <div style={styles.editorContainer}>
            <textarea
              style={styles.textarea}
              value={code}
              onChange={(e) => setCode(e.target.value)}
              onKeyDown={handleKeyDown}
              spellCheck={false}
              placeholder="Enter your code here..."
            />
          </div>
        </div>

        {/* Divider */}
        <div style={styles.divider} className="divider" />

        {/* Right Pane - Output */}
        <div style={styles.pane}>
          <div style={styles.paneHeader}>
            <div style={styles.paneTitle}>
              <span style={{color: targetInfo?.color}}>{targetInfo?.icon}</span>
              <span style={styles.paneTitleText}>Hardware Output</span>
            </div>
            <div style={{display: 'flex', alignItems: 'center', gap: '12px'}}>
              <div style={styles.tabs}>
                <button 
                  style={activeTab === 'output' ? styles.tabActive : styles.tab}
                  onClick={() => setActiveTab('output')}
                >
                  Code
                </button>
                <button 
                  style={activeTab === 'logs' ? styles.tabActive : styles.tab}
                  onClick={() => setActiveTab('logs')}
                >
                  Logs
                </button>
              </div>
              <select 
                style={styles.select}
                value={targetLang}
                onChange={(e) => setTargetLang(e.target.value)}
              >
                {TARGETS.map(t => (
                  <option key={t.id} value={t.id}>{t.icon} {t.name}</option>
                ))}
              </select>
            </div>
          </div>
          <div style={styles.editorContainer}>
            {isCompiling ? (
              <div style={styles.loadingOverlay}>
                <div style={styles.spinner} />
                <span style={{color: '#58a6ff', fontSize: '13px'}}>Compiling...</span>
              </div>
            ) : activeTab === 'output' ? (
              <textarea
                ref={outputRef}
                style={styles.outputTextarea}
                value={output}
                readOnly
                spellCheck={false}
              />
            ) : (
              <div style={styles.logsContainer}>
                {logs.map((log, i) => (
                  <div key={i} style={{
                    ...styles.logLine,
                    color: log.includes('[SUCCESS]') ? '#7ee787' :
                           log.includes('[ERROR]') ? '#f85149' :
                           log.includes('[PASS]') ? '#58a6ff' :
                           log.includes('[INFO]') ? '#8b949e' : '#c9d1d9'
                  }}>
                    {log}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer style={styles.footer}>
        <div style={{display: 'flex', gap: '16px'}}>
          <span>Ln {code.split('\n').length}, Col 1</span>
          <span>UTF-8</span>
          {compileTime && <span>Compiled in {compileTime}ms</span>}
        </div>
        <div style={{display: 'flex', gap: '16px'}}>
          <span>VIBEE v0.9.99</span>
          <span>Trinity Core v5.0</span>
          <span>φ² + 1/φ² = 3</span>
        </div>
      </footer>
    </div>
  );
}
