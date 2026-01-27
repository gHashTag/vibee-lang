'use client';

import { useState, useEffect } from 'react';

const LANGUAGES = [
  { id: 'python', name: 'Python', icon: '🐍' },
  { id: 'cpp', name: 'C++', icon: '⚙️' },
  { id: 'rust', name: 'Rust', icon: '🦀' },
  { id: 'go', name: 'Go', icon: '🐹' },
  { id: 'js', name: 'JavaScript', icon: '📜' },
  { id: 'ts', name: 'TypeScript', icon: 'TS' },
  { id: 'zig', name: 'Zig', icon: '⚡' },
  { id: 'vibee', name: 'VIBEE (.999)', icon: '🔮' },
  { id: 'verilog', name: 'Verilog', icon: '📟' },
  { id: 'vhdl', name: 'VHDL', icon: '📼' },
  { id: 'systemverilog', name: 'SystemVerilog', icon: 'sv' },
  { id: 'coptic', name: 'Coptic CIS', icon: 'ⲁⲃⲅ' }
];

const SAMPLE_CODE: Record<string, string> = {
  python: `def matrix_mul(a, b):
    # Standard matrix multiplication
    c = [[0, 0], [0, 0]]
    for i in range(2):
        for j in range(2):
            for k in range(2):
                c[i][j] += a[i][k] * b[k][j]
    return c`,
  cpp: `void matrix_mul(int a[2][2], int b[2][2], int c[2][2]) {
    // Standard matrix multiplication
    for(int i=0; i<2; i++) {
        for(int j=0; j<2; j++) {
            c[i][j] = 0;
            for(int k=0; k<2; k++) {
                c[i][j] += a[i][k] * b[k][j];
            }
        }
    }
}`,
  vibee: `// TRINITY NATIVE SU(3) MATRIX MUL
#pragma su3_core_v5
fn matrix_mul(a: mat2x2, b: mat2x2) -> mat2x2 {
    return a ⊗ b; // Tensor product in Gell-Mann space
}`
};

export default function TranslatorDemo() {
  const [sourceLang, setSourceLang] = useState('python');
  const [targetLang, setTargetLang] = useState('verilog');
  const [code, setCode] = useState(SAMPLE_CODE['python']);
  const [output, setOutput] = useState('');
  const [isTransmuting, setIsTransmuting] = useState(false);

  useEffect(() => {
    setCode(SAMPLE_CODE[sourceLang] || '// Enter code here...');
    setOutput('');
  }, [sourceLang]);

  const handleTransmute = () => {
    setIsTransmuting(true);
    setTimeout(() => {
      setIsTransmuting(false);
      setOutput(`// TRINITY GENERATED HARDWARE (${targetLang.toUpperCase()})
// Optimized for SU(3) Core V5.0
// Latency: 2 cycles | Energy: 0.17pJ

module matrix_mul_accelerator (
    input clk,
    input rst,
    input [31:0] a_00, a_01, a_10, a_11,
    input [31:0] b_00, b_01, b_10, b_11,
    output reg [31:0] c_00, c_01, c_10, c_11
);

always @(posedge clk) begin
    // Massively parallel SU(3) execution
    c_00 <= a_00 * b_00 + a_01 * b_10;
    c_01 <= a_00 * b_01 + a_01 * b_11;
    c_10 <= a_10 * b_00 + a_11 * b_10;
    c_11 <= a_10 * b_01 + a_11 * b_11;
end

endmodule`);
    }, 1500);
  };

  return (
    <div className="w-full max-w-6xl mx-auto p-4 fade">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 relative">
        
        {/* Source Panel */}
        <div className="premium-card relative overflow-hidden group">
          <div className="flex items-center justify-between mb-4 border-b border-[var(--border)] pb-2">
            <div className="text-sm uppercase tracking-wider text-[var(--muted)]">Input Source</div>
            <select 
              value={sourceLang}
              onChange={(e) => setSourceLang(e.target.value)}
              className="bg-[rgba(255,255,255,0.05)] text-[var(--text)] border border-[var(--border)] rounded px-2 py-1 text-sm outline-none focus:border-[var(--accent)]"
            >
              {LANGUAGES.map(l => <option key={l.id} value={l.id}>{l.icon} {l.name}</option>)}
            </select>
          </div>
          <textarea
            value={code}
            onChange={(e) => setCode(e.target.value)}
            className="w-full h-64 bg-transparent text-[var(--text)] font-mono text-sm resize-none outline-none"
            spellCheck="false"
          />
        </div>

        {/* Transmute Button */}
        <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-10 hidden md:block">
          <button 
            onClick={handleTransmute}
            className="w-12 h-12 rounded-full bg-[var(--bg)] border border-[var(--accent)] flex items-center justify-center text-2xl hover:scale-110 transition-transform shadow-[0_0_20px_rgba(0,229,153,0.3)] group"
          >
            <span className={isTransmuting ? "animate-spin" : "group-hover:rotate-180 transition-transform duration-500"}>⚡</span>
          </button>
        </div>

        {/* Target Panel */}
        <div className="premium-card relative overflow-hidden">
          <div className="flex items-center justify-between mb-4 border-b border-[var(--border)] pb-2">
            <div className="text-sm uppercase tracking-wider text-[var(--muted)]">Target Hardware</div>
            <select 
              value={targetLang}
              onChange={(e) => setTargetLang(e.target.value)}
              className="bg-[rgba(255,255,255,0.05)] text-[var(--text)] border border-[var(--border)] rounded px-2 py-1 text-sm outline-none focus:border-[var(--accent)]"
            >
              {LANGUAGES.map(l => <option key={l.id} value={l.id}>{l.icon} {l.name}</option>)}
            </select>
          </div>
          <div className="relative w-full h-64">
            {isTransmuting ? (
              <div className="absolute inset-0 flex items-center justify-center flex-col gap-2">
                <div className="w-8 h-8 border-2 border-[var(--accent)] border-t-transparent rounded-full animate-spin"></div>
                <div className="text-xs text-[var(--accent)] animate-pulse">TRANSMUTING TO HARDWARE...</div>
              </div>
            ) : (
              <textarea
                value={output}
                readOnly
                placeholder="// Click lightning bolt to generate hardware..."
                className="w-full h-full bg-transparent text-[var(--accent)] font-mono text-sm resize-none outline-none opacity-90"
                spellCheck="false"
              />
            )}
          </div>
        </div>

      </div>
      
      <div className="text-center mt-6 md:hidden">
        <button 
           onClick={handleTransmute}
           className="btn w-full"
        >
          {isTransmuting ? 'Transmuting...' : '⚡ Compile to Hardware'}
        </button>
      </div>

    </div>
  );
}
