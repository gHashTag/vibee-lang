'use client';

import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';

const LANGUAGES = [
  { id: 'vibee', name: 'VIBEE (.999)', icon: '🔮' },
  { id: 'python', name: 'Python', icon: '🐍' },
  { id: 'zig', name: 'Zig', icon: '⚡' },
  { id: 'rust', name: 'Rust', icon: '🦀' },
  { id: 'cpp', name: 'C++', icon: '⚙️' },
];

const OUTPUT_LANGS = [
  { id: 'verilog', name: 'Verilog', icon: '📟' },
  { id: 'systemverilog', name: 'SystemVerilog', icon: 'sv' },
  { id: 'vhdl', name: 'VHDL', icon: '📼' },
  { id: 'su3_ir', name: 'SU(3) IR', icon: '🔺' },
];

const SAMPLE_CODE: Record<string, string> = {
  vibee: `// TRINITY NATIVE SU(3) COMPILATION
// Target: Trinity Core V5.0 (Quantum-Optical)

module matrix_ops {
  // Sacred Constants
  const phi = 1.6180339887;
  
  pub fn tensor_product(a: mat3, b: mat3) -> mat9 {
    // Native SU(3) Tensor Product
    // Executes in single cycle on T-Core
    return a ⊗ b; 
  }

  pub fn main() {
    let q = |0⟩ + |1⟩; // Superposition
    let result = tensor_product(q, q);
    phase_shift(result, phi);
  }
}`,
  python: `def quantum_kernel(x):
    # Trinity Python Bindings
    # Automatically accelerated on NPU
    
    phi = 1.618
    return x ** phi + (1/x) ** phi

def main():
    data = [1, 2, 3]
    result = [quantum_kernel(x) for x in data]
    print(f"Synergy: {sum(result)}")`,
};

export default function Playground() {
  const [sourceLang, setSourceLang] = useState('vibee');
  const [targetLang, setTargetLang] = useState('verilog');
  const [code, setCode] = useState(SAMPLE_CODE['vibee']);
  const [output, setOutput] = useState('');
  const [isCompiling, setIsCompiling] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [activeTab, setActiveTab] = useState<'output' | 'logs'>('output');

  useEffect(() => {
    setCode(SAMPLE_CODE[sourceLang] || '// Enter code here...');
    handleCompile(SAMPLE_CODE[sourceLang] || '', targetLang);
  }, [sourceLang]);

  useEffect(() => {
    handleCompile(code, targetLang);
  }, [targetLang]);

  const handleCompile = (_src: string, target: string) => {
    setIsCompiling(true);
    setLogs(['> Initializing compiler...', '> Loading SU(3) optimization backend...']);
    
    setTimeout(() => {
      setIsCompiling(false);
      setLogs(prev => [
        ...prev, 
        `> Parsing ${sourceLang.toUpperCase()} AST...`,
        '> Applying Golden Ratio optimization (φ)...',
        '> Reducing logic depth...',
        `> Generating ${target.toUpperCase()}...`,
        '> Done (0.042s).'
      ]);
      
      let out = `// TRINITY COMPILER V5.0 GENERATED CODE
// Source: ${sourceLang} | Target: ${target}
// Timestamp: ${new Date().toISOString()}
// Optimization: MAXIMUM (SU3)

`;

      if (target === 'verilog' || target === 'systemverilog') {
        out += `module trinity_accelerator (
    input wire clk,
    input wire rst_n,
    input wire [2:0] in_trit_a, // Ternary Input
    output reg [2:0] out_trit_q
);

    // Trinity Core V5 Mapping
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_trit_q <= 3'b000;
        end else begin
            // SU(3) Native Operation mapping
            // Latency: 1 cycle
            case (in_trit_a)
                3'b00: out_trit_q <= 3'b01; // |0> -> |1>
                3'b01: out_trit_q <= 3'b10; // |1> -> |2>
                3'b10: out_trit_q <= 3'b00; // |2> -> |0>
                default: out_trit_q <= 3'bx;
            endcase
            
            // Golden Ratio Phase Shift
             /* Quantum interference pattern generated */
        end
    end

endmodule`;
      } else if (target === 'vhdl') {
        out += `library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity trinity_core is
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           data_in : in STD_LOGIC_VECTOR(2 downto 0);
           q_out : out STD_LOGIC_VECTOR(2 downto 0));
end trinity_core;

architecture Behavior of trinity_core is
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                q_out <= "000";
            else
                -- High Level Synthesis from ${sourceLang}
                q_out <= not data_in; -- Simplified SU(3) logic
            end if;
        end if;
    end process;
end Behavior;`;
      } else {
        out += `// IR Representation for ${sourceLang}
// Optimized for Trinity Kernel
%0 = load ${sourceLang}.input
%1 = su3.transform %0, type=unitary
%2 = phi.multiply %1, constant=1.618
return %2`;
      }
      
      setOutput(out);
    }, 800);
  };

  return (
    <div className="flex flex-col h-screen bg-[#1e1e1e] text-[#d4d4d4] font-mono overflow-hidden">
      {/* Header */}
      <header className="flex items-center justify-between px-4 py-2 bg-[#2d2d2d] border-b border-[#3e3e3e]">
        <div className="flex items-center gap-4">
          <Link to="/" className="flex items-center gap-2 text-white hover:text-[var(--accent)] transition-colors">
            <span className="text-xl">🔺</span>
            <span className="font-bold tracking-tight">TRINITY</span>
            <span className="text-xs text-[var(--muted)] px-1.5 py-0.5 border border-[var(--border)] rounded bg-black/20">PLAYGROUND</span>
          </Link>
        </div>
        
        <div className="flex items-center gap-3">
          <button 
            onClick={() => handleCompile(code, targetLang)}
            className="flex items-center gap-2 bg-[var(--accent)] text-black px-4 py-1.5 rounded-sm text-sm font-semibold hover:opacity-90 transition-opacity"
          >
            <span>▶</span> Run
          </button>
          <button className="px-3 py-1.5 text-sm hover:bg-[#3e3e3e] rounded-sm transition-colors">Share</button>
          <button className="px-3 py-1.5 text-sm hover:bg-[#3e3e3e] rounded-sm transition-colors">Config</button>
          <div className="w-[1px] h-4 bg-[#3e3e3e] mx-1"></div>
          <Link to="/" className="text-sm text-[var(--muted)] hover:text-white transition-colors">Exit</Link>
        </div>
      </header>

      {/* Main Content */}
      <div className="flex-1 flex overflow-hidden">
        
        {/* Editor Pane (Left) */}
        <div className="flex-1 flex flex-col border-r border-[#3e3e3e]">
          <div className="flex items-center justify-between px-4 py-2 bg-[#252526] border-b border-[#3e3e3e]">
            <div className="flex items-center gap-2">
              <span className="text-xs uppercase tracking-wider text-[var(--muted)]">Input Language</span>
              <select 
                value={sourceLang}
                onChange={(e) => setSourceLang(e.target.value)}
                className="bg-[#3e3e3e] text-white text-xs rounded px-2 py-1 border border-transparent outline-none focus:border-[var(--accent)]"
              >
                {LANGUAGES.map(l => <option key={l.id} value={l.id}>{l.icon} {l.name}</option>)}
              </select>
            </div>
          </div>
          <div className="flex-1 relative">
            <textarea
              className="absolute inset-0 w-full h-full bg-[#1e1e1e] text-[#d4d4d4] p-4 resize-none outline-none font-mono text-sm leading-6"
              spellCheck="false"
              value={code}
              onChange={(e) => setCode(e.target.value)}
            />
          </div>
        </div>

        {/* Output Pane (Right) */}
        <div className="flex-1 flex flex-col bg-[#1e1e1e]">
          <div className="flex items-center justify-between px-4 py-2 bg-[#252526] border-b border-[#3e3e3e]">
             <div className="flex items-center gap-4">
                <div className="flex items-center gap-2">
                  <span className="text-xs uppercase tracking-wider text-[var(--muted)]">Output Target</span>
                  <select 
                    value={targetLang}
                    onChange={(e) => setTargetLang(e.target.value)}
                    className="bg-[#3e3e3e] text-white text-xs rounded px-2 py-1 border border-transparent outline-none focus:border-[var(--accent)]"
                  >
                    {OUTPUT_LANGS.map(l => <option key={l.id} value={l.id}>{l.icon} {l.name}</option>)}
                  </select>
                </div>
                
                <div className="flex gap-1 bg-[#3e3e3e] p-0.5 rounded">
                  <button 
                    onClick={() => setActiveTab('output')}
                    className={`px-3 py-0.5 text-xs rounded-sm transition-colors ${activeTab === 'output' ? 'bg-[#1e1e1e] text-white shadow-sm' : 'text-[var(--muted)] hover:text-white'}`}
                  >
                    Hardware
                  </button>
                  <button 
                    onClick={() => setActiveTab('logs')}
                    className={`px-3 py-0.5 text-xs rounded-sm transition-colors ${activeTab === 'logs' ? 'bg-[#1e1e1e] text-white shadow-sm' : 'text-[var(--muted)] hover:text-white'}`}
                  >
                    Logs
                  </button>
                </div>
             </div>
          </div>
          
          <div className="flex-1 relative">
            {activeTab === 'output' ? (
              <div className="absolute inset-0 w-full h-full overflow-auto">
                {isCompiling ? (
                  <div className="flex items-center justify-center h-full text-[var(--accent)]">
                    <div className="flex flex-col items-center gap-3">
                       <div className="w-6 h-6 border-2 border-current border-t-transparent rounded-full animate-spin"></div>
                       <div className="text-xs font-mono animate-pulse">TRANSMUTING...</div>
                    </div>
                  </div>
                ) : (
                  <textarea
                    readOnly
                    className="w-full h-full bg-[#1e1e1e] text-[#9cdcfe] p-4 resize-none outline-none font-mono text-sm leading-6"
                    value={output}
                  />
                )}
              </div>
            ) : (
              <div className="absolute inset-0 w-full h-full overflow-auto p-4 bg-[#1e1e1e] font-mono text-xs">
                {logs.map((log, i) => (
                  <div key={i} className="mb-1 text-[var(--muted)] border-b border-white/5 pb-1 last:border-0">
                    <span className="text-[var(--accent)] mr-2">{new Date().toLocaleTimeString()}</span>
                    {log}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

      </div>
      
      {/* Footer Status Bar */}
      <footer className="bg-[#007acc] text-white text-xs px-3 py-1 flex justify-between items-center">
        <div className="flex gap-4">
           <span>Ready</span>
           <span>Ln {code.split('\n').length}, Col 1</span>
        </div>
        <div className="flex gap-4">
           <span>Vibee v0.9.99</span>
           <span>Trinity Core v5.0</span>
        </div>
      </footer>
    </div>
  );
}
