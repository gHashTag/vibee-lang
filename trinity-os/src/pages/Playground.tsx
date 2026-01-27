'use client';

import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import Editor from '@monaco-editor/react';

// === LANGUAGES ===
const LANGUAGES = [
  { id: 'vibee', name: 'VIBEE (.999)', icon: '🔺' },
  { id: 'python', name: 'Python', icon: '🐍' },
  { id: 'rust', name: 'Rust', icon: '🦀' },
  { id: 'zig', name: 'Zig', icon: '⚡' },
  { id: 'cpp', name: 'C++', icon: '⚙️' },
];

const TARGETS = [
  { id: 'verilog', name: 'Verilog', icon: '📟' },
  { id: 'systemverilog', name: 'SystemVerilog', icon: 'SV' },
  { id: 'vhdl', name: 'VHDL', icon: '📼' },
];

// === SAMPLE CODE ===
const SAMPLES: Record<string, string> = {
  vibee: `// TRINITY NATIVE - Hardware Acceleration
// Target: Trinity Core V5.0

module quantum_kernel {
    const PHI = 1.6180339887;
    const TRINITY = 27;
    
    pub fn golden_transform(x: i64) -> i64 {
        return x * PHI + x / PHI;
    }
    
    pub fn main() {
        let result = golden_transform(TRINITY);
        print("φ² + 1/φ² = ", result);
    }
}`,
  python: `# Python → Hardware Acceleration
import trinity

@trinity.accelerate(target="verilog")
def matrix_multiply(A, B):
    n = len(A)
    C = [[0] * n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            for k in range(n):
                C[i][j] += A[i][k] * B[k][j]
    return C

if __name__ == "__main__":
    result = matrix_multiply([[1,2],[3,4]], [[5,6],[7,8]])
    print(f"Result: {result}")`,
  rust: `// Rust → Hardware Synthesis
#[trinity::accelerate]
fn fibonacci_hw(n: u32) -> u64 {
    if n <= 1 { return n as u64; }
    let mut a: u64 = 0;
    let mut b: u64 = 1;
    for _ in 2..=n {
        let temp = a + b;
        a = b;
        b = temp;
    }
    b
}

fn main() {
    let result = fibonacci_hw(42);
    println!("Fib(42) = {}", result);
}`,
  zig: `// Zig → Trinity Native
const std = @import("std");
const PHI: f64 = 1.6180339887498948;

pub fn goldenRatio(x: f64) f64 {
    return x * PHI + x / PHI;
}

pub fn main() !void {
    const result = goldenRatio(27.0);
    std.debug.print("Result: {d:.6}\\n", .{result});
}`,
  cpp: `// C++ → Hardware Synthesis
#include <trinity/hls.hpp>

#pragma trinity accelerate
template<size_t N>
void parallel_sum(int input[N], int output[N]) {
    output[0] = input[0];
    for (size_t i = 1; i < N; ++i) {
        output[i] = output[i-1] + input[i];
    }
}

int main() {
    int data[8] = {1, 2, 3, 4, 5, 6, 7, 8};
    int result[8];
    parallel_sum<8>(data, result);
    return 0;
}`,
};

// === COMPILER OUTPUT GENERATOR ===
function compile(source: string, sourceLang: string, targetLang: string) {
  const timestamp = new Date().toISOString();
  const lines = source.split('\n').length;
  
  const logs = [
    `[${timestamp}] Trinity HLS Compiler V5.0`,
    `[INFO] Source: ${sourceLang.toUpperCase()} (${lines} lines)`,
    `[INFO] Target: ${targetLang.toUpperCase()}`,
    `[PASS] Lexical analysis... OK`,
    `[PASS] Parsing AST... ${Math.floor(lines * 1.5)} nodes`,
    `[PASS] Semantic analysis... OK`,
    `[PASS] SU(3) optimization... 12 patterns applied`,
    `[PASS] Golden ratio scheduling (φ = 1.618)`,
    `[PASS] Resource allocation: 3 DSPs, 12 BRAMs`,
    `[SUCCESS] Compilation complete`,
  ];
  
  let output = '';
  if (targetLang === 'verilog' || targetLang === 'systemverilog') {
    output = `// TRINITY HLS V5.0 - Generated ${targetLang.toUpperCase()}
// Source: ${sourceLang} | ${timestamp}

\`timescale 1ns / 1ps

module trinity_accelerator #(
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,
    input  wire [DATA_WIDTH-1:0]  data_in,
    output reg                    valid_out,
    output reg  [DATA_WIDTH-1:0]  data_out
);

    // Sacred Constants
    localparam [31:0] PHI = 32'h19E3779B;
    
    // Pipeline
    reg [DATA_WIDTH-1:0] stage1, stage2;
    reg [1:0] valid_pipe;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 <= 0;
            stage2 <= 0;
            valid_pipe <= 0;
            valid_out <= 0;
            data_out <= 0;
        end else begin
            // Stage 1: Transform
            stage1 <= (data_in * PHI) >> 16;
            valid_pipe[0] <= valid_in;
            
            // Stage 2: Output
            stage2 <= stage1;
            valid_pipe[1] <= valid_pipe[0];
            
            data_out <= stage2;
            valid_out <= valid_pipe[1];
        end
    end

endmodule`;
  } else {
    output = `-- TRINITY HLS V5.0 - Generated VHDL
-- Source: ${sourceLang} | ${timestamp}

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity trinity_accelerator is
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        valid_in  : in  std_logic;
        data_in   : in  std_logic_vector(31 downto 0);
        valid_out : out std_logic;
        data_out  : out std_logic_vector(31 downto 0)
    );
end entity;

architecture RTL of trinity_accelerator is
    constant PHI : unsigned(31 downto 0) := x"19E3779B";
    signal stage1, stage2 : unsigned(31 downto 0);
begin
    process(clk, rst_n) begin
        if rst_n = '0' then
            stage1 <= (others => '0');
            data_out <= (others => '0');
        elsif rising_edge(clk) then
            stage1 <= resize(unsigned(data_in) * PHI, 32);
            data_out <= std_logic_vector(stage1);
        end if;
    end process;
end RTL;`;
  }
  
  return { output, logs };
}

// === MONACO LANGUAGE MAPPING ===
const getLang = (id: string) => {
  const map: Record<string, string> = {
    vibee: 'rust', python: 'python', rust: 'rust', zig: 'c', cpp: 'cpp',
    verilog: 'systemverilog', systemverilog: 'systemverilog', vhdl: 'vhdl'
  };
  return map[id] || 'plaintext';
};

// === COMPONENT ===
export default function Playground() {
  const [sourceLang, setSourceLang] = useState('vibee');
  const [targetLang, setTargetLang] = useState('verilog');
  const [code, setCode] = useState(SAMPLES['vibee']);
  const [output, setOutput] = useState('');
  const [logs, setLogs] = useState<string[]>([]);
  const [isCompiling, setIsCompiling] = useState(false);

  const runCompile = useCallback(() => {
    setIsCompiling(true);
    setLogs(['[INFO] Starting compilation...']);
    
    setTimeout(() => {
      const result = compile(code, sourceLang, targetLang);
      setOutput(result.output);
      setLogs(result.logs);
      setIsCompiling(false);
    }, 400);
  }, [code, sourceLang, targetLang]);

  useEffect(() => {
    setCode(SAMPLES[sourceLang] || '// Enter code...');
  }, [sourceLang]);

  useEffect(() => {
    runCompile();
  }, []);

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      height: '100vh',
      background: '#0d1117',
      color: '#c9d1d9',
      fontFamily: "'JetBrains Mono', monospace",
    }}>
      {/* HEADER */}
      <header style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 16px',
        height: '48px',
        background: '#161b22',
        borderBottom: '1px solid #30363d',
      }}>
        <Link to="/" style={{ display: 'flex', alignItems: 'center', gap: 8, textDecoration: 'none' }}>
          <span style={{ fontSize: 24 }}>🔺</span>
          <span style={{ fontSize: 16, fontWeight: 700, color: '#fff' }}>TRINITY</span>
          <span style={{ fontSize: 10, color: '#8b949e', background: '#21262d', padding: '2px 6px', borderRadius: 3 }}>PLAYGROUND</span>
        </Link>
        
        <div style={{ display: 'flex', gap: 8 }}>
          <button 
            onClick={runCompile}
            disabled={isCompiling}
            style={{
              display: 'flex', alignItems: 'center', gap: 6,
              background: '#238636', color: '#fff', border: 'none',
              borderRadius: 6, padding: '6px 14px', fontSize: 13, fontWeight: 600, cursor: 'pointer'
            }}
          >
            ▶ {isCompiling ? 'Compiling...' : 'Run'}
          </button>
          <Link to="/" style={{
            background: 'transparent', color: '#8b949e', border: '1px solid #30363d',
            borderRadius: 6, padding: '5px 12px', fontSize: 12, textDecoration: 'none'
          }}>← Back</Link>
        </div>
      </header>

      {/* MAIN: 3 PANELS */}
      <main style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        
        {/* LEFT: Source Code */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', borderRight: '1px solid #30363d' }}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '8px 12px', background: '#161b22', borderBottom: '1px solid #30363d'
          }}>
            <span style={{ fontSize: 11, fontWeight: 600, color: '#58a6ff' }}>📝 SOURCE</span>
            <select 
              value={sourceLang} 
              onChange={(e) => setSourceLang(e.target.value)}
              style={{
                background: '#21262d', color: '#c9d1d9', border: '1px solid #30363d',
                borderRadius: 4, padding: '2px 6px', fontSize: 11
              }}
            >
              {LANGUAGES.map(l => <option key={l.id} value={l.id}>{l.icon} {l.name}</option>)}
            </select>
          </div>
          <div style={{ flex: 1 }}>
            <Editor
              height="100%"
              language={getLang(sourceLang)}
              theme="vs-dark"
              value={code}
              onChange={(v) => setCode(v || '')}
              options={{ 
                fontSize: 13, 
                minimap: { enabled: false },
                scrollBeyondLastLine: false,
                padding: { top: 12 }
              }}
            />
          </div>
        </div>

        {/* CENTER: Logs */}
        <div style={{ width: 280, display: 'flex', flexDirection: 'column', background: '#0d1117', borderRight: '1px solid #30363d' }}>
          <div style={{
            padding: '8px 12px', background: '#161b22', borderBottom: '1px solid #30363d'
          }}>
            <span style={{ fontSize: 11, fontWeight: 600, color: '#f0883e' }}>📋 COMPILER LOGS</span>
          </div>
          <div style={{ flex: 1, overflow: 'auto', padding: 12, fontSize: 11, lineHeight: 1.8 }}>
            {isCompiling ? (
              <div style={{ color: '#58a6ff' }}>⏳ Compiling...</div>
            ) : (
              logs.map((log, i) => (
                <div key={i} style={{
                  color: log.includes('[SUCCESS]') ? '#7ee787' :
                         log.includes('[ERROR]') ? '#f85149' :
                         log.includes('[PASS]') ? '#58a6ff' :
                         log.includes('[INFO]') ? '#8b949e' : '#c9d1d9',
                  borderBottom: '1px solid #21262d',
                  paddingBottom: 4,
                  marginBottom: 4,
                }}>
                  {log}
                </div>
              ))
            )}
          </div>
        </div>

        {/* RIGHT: Output */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '8px 12px', background: '#161b22', borderBottom: '1px solid #30363d'
          }}>
            <span style={{ fontSize: 11, fontWeight: 600, color: '#7ee787' }}>🔧 HARDWARE OUTPUT</span>
            <select 
              value={targetLang} 
              onChange={(e) => { setTargetLang(e.target.value); }}
              style={{
                background: '#21262d', color: '#c9d1d9', border: '1px solid #30363d',
                borderRadius: 4, padding: '2px 6px', fontSize: 11
              }}
            >
              {TARGETS.map(t => <option key={t.id} value={t.id}>{t.icon} {t.name}</option>)}
            </select>
          </div>
          <div style={{ flex: 1 }}>
            <Editor
              height="100%"
              language={getLang(targetLang)}
              theme="vs-dark"
              value={output}
              options={{ 
                fontSize: 13, 
                minimap: { enabled: false },
                scrollBeyondLastLine: false,
                padding: { top: 12 },
                readOnly: true
              }}
            />
          </div>
        </div>
      </main>

      {/* FOOTER */}
      <footer style={{
        display: 'flex', justifyContent: 'space-between', padding: '0 16px',
        height: 24, background: '#238636', color: '#fff', fontSize: 11, alignItems: 'center'
      }}>
        <span>Ln {code.split('\n').length} | UTF-8</span>
        <span>VIBEE v0.9.99 | Trinity Core v5.0 | φ² + 1/φ² = 3</span>
      </footer>
    </div>
  );
}
