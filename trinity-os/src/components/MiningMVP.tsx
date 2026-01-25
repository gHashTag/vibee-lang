"use client";
import { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const COPTIC_CHARS = "ⲁⲃⲅⲇⲉⲋⲍⲏⲑⲓⲕⲗⲙⲛⲝⲟⲡⲣⲥⲧⲩⲫⲭⲱϣϥϧϩϫϭϯ";

export default function MiningMVP() {
  const [isMining, setIsMining] = useState(false);
  const [hashrate, setHashrate] = useState(0);
  const [efficiency, setEfficiency] = useState(578.8);
  const [satoshi, setSatoshi] = useState(0);
  const [wallet, setWallet] = useState<string | null>(null);
  const [logs, setLogs] = useState<string[]>([]);
  const logEndRef = useRef<HTMLDivElement>(null);

  const connectWallet = () => {
    // Simulated Wallet Connection (e.g., Ledger / WalletConnect)
    const mockAddr = `0xTRINITY_${Math.random().toString(16).substring(2, 10).toUpperCase()}`;
    setWallet(mockAddr);
    setLogs(prev => [...prev, `WALLET_CONNECTED: ${mockAddr} via LEDGER_NATIVE`]);
  };

  // Simulation Logic
  useEffect(() => {
    let interval: any;
    if (isMining) {
      interval = setInterval(() => {
        // SU(3) Simulated Hashrate (Randomized for "Realism")
        const baseHash = Math.random() * 100 + 450;
        setHashrate(baseHash);
        setEfficiency(578.8 + Math.random() * 0.4);
        
        // Satoshi Accumulation
        setSatoshi(prev => prev + (baseHash * 0.0000001));

        // Generate Coptic Opcode Logs
        const newLog = `SU3_OP: ${COPTIC_CHARS[Math.floor(Math.random() * COPTIC_CHARS.length)]} -> VIBEE_TX_${Math.random().toString(36).substring(7).toUpperCase()}`;
        setLogs(prev => [...prev.slice(-15), newLog]);
      }, 200);
    } else {
      setHashrate(0);
    }
    return () => clearInterval(interval);
  }, [isMining]);

  useEffect(() => {
    logEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [logs]);

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: '#000', 
      color: '#fff', 
      display: 'flex', 
      flexDirection: 'column',
      padding: '1.5rem',
      fontFamily: 'Inter, system-ui, -apple-system, sans-serif',
      position: 'relative',
      overflow: 'hidden'
    }}>
      {/* Simulation Banner */}
      <div style={{ 
        background: 'rgba(255, 69, 58, 0.1)', 
        color: '#ff453a', 
        fontSize: '0.6rem', 
        padding: '4px', 
        textAlign: 'center', 
        borderRadius: '4px',
        marginBottom: '1rem',
        border: '1px solid rgba(255, 69, 58, 0.2)',
        fontWeight: 600,
        textTransform: 'uppercase',
        zIndex: 10
      }}>
        VIBEE_OS: Active SU(3) Core Simulation (Native Protocol Running on ARM64)
      </div>

      {/* Header Stat Bar */}
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '2rem', zIndex: 1 }}>
        <div onClick={connectWallet} style={{ cursor: 'pointer' }}>
          <div style={{ fontSize: '0.65rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>
            {wallet ? 'Account Connected' : 'Bitcoin Wallet'}
          </div>
          <div style={{ fontSize: '1.2rem', fontWeight: 600, color: wallet ? 'var(--accent)' : '#fff' }}>
            {wallet ? `₿ ${satoshi.toFixed(8)}` : 'DISCONNECTED'}
          </div>
          {wallet && <div style={{ fontSize: '0.5rem', color: 'var(--muted)', marginTop: '2px' }}>{wallet}</div>}
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: '0.65rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>Native Port</div>
          <div style={{ fontSize: '0.8rem', fontWeight: 500 }}>VIBEE_OS_V5.PRO</div>
        </div>
      </div>

      {/* Main Core View */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', zIndex: 1 }}>
        <div style={{ position: 'relative', width: '300px', height: '300px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {/* Energy Particles (PAS) */}
          <AnimatePresence>
            {isMining && [0, 1, 2, 3, 4, 5].map((i) => (
              <motion.div
                key={`particle-${i}`}
                initial={{ opacity: 0, x: 0, y: 0 }}
                animate={{ 
                  opacity: [0, 1, 0], 
                  x: Math.cos(i * 60 * Math.PI / 180) * 120,
                  y: Math.sin(i * 60 * Math.PI / 180) * 120,
                }}
                transition={{ duration: 1.5, repeat: Infinity, delay: i * 0.2, ease: "easeOut" }}
                style={{
                  position: 'absolute',
                  width: '4px',
                  height: '4px',
                  background: 'var(--accent)',
                  borderRadius: '50%',
                  boxShadow: '0 0 10px var(--accent)'
                }}
              />
            ))}
          </AnimatePresence>

          {/* Pulsing SU(3) Waves */}
          <AnimatePresence>
            {isMining && [1, 2, 3].map((i) => (
              <motion.div
                key={i}
                initial={{ scale: 0.8, opacity: 0.5 }}
                animate={{ scale: 1.5, opacity: 0 }}
                transition={{ duration: 2, repeat: Infinity, delay: i * 0.6 }}
                style={{
                  position: 'absolute',
                  width: '100%',
                  height: '100%',
                  border: '1px solid var(--accent)',
                  borderRadius: '50%',
                  filter: 'blur(4px)',
                  opacity: 0.3
                }}
              />
            ))}
          </AnimatePresence>

          <motion.div 
            animate={isMining ? { scale: [1, 1.02, 1], rotate: 360 } : {}}
            transition={{ duration: 8, repeat: Infinity, ease: "linear" }}
            style={{ 
              width: '180px', 
              height: '180px', 
              borderRadius: '50%', 
              background: 'rgba(0, 229, 153, 0.08)',
              border: '2px solid rgba(0, 229, 153, 0.4)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: isMining ? '0 0 50px rgba(0, 229, 153, 0.25)' : 'none',
              position: 'relative'
            }}
          >
            {/* Inner Ring */}
            <div style={{
              position: 'absolute',
              width: '90%',
              height: '90%',
              border: '1px dashed rgba(255,255,255,0.1)',
              borderRadius: '50%'
            }} />
            
            <div style={{ textAlign: 'center', zIndex: 2 }}>
              <div style={{ fontSize: '2.8rem', fontWeight: 900, color: isMining ? 'var(--accent)' : 'var(--muted)', lineHeight: 1, letterSpacing: '-0.02em' }}>
                SU(3)
              </div>
              <div style={{ fontSize: '0.6rem', textTransform: 'uppercase', letterSpacing: '0.3em', marginTop: '0.4rem', opacity: 0.8, fontWeight: 600 }}>
                NATIVE
              </div>
            </div>
          </motion.div>
        </div>

        {/* Live Metrics Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', width: '100%', marginTop: '2rem' }}>
          <div className="premium-card compact" style={{ padding: '1.2rem', textAlign: 'center', borderColor: isMining ? 'var(--accent)' : 'var(--border)' }}>
            <div style={{ fontSize: '0.6rem', color: 'var(--muted)', textTransform: 'uppercase', marginBottom: '0.6rem', letterSpacing: '0.05em' }}>PAS Efficiency</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700, color: 'var(--accent)' }}>{efficiency.toFixed(1)}x</div>
            <div style={{ fontSize: '0.5rem', color: 'var(--accent)', opacity: 0.6, marginTop: '0.3rem', fontWeight: 600 }}>HARVESTING ENTROPY</div>
          </div>
          <div className="premium-card compact" style={{ padding: '1.2rem', textAlign: 'center' }}>
            <div style={{ fontSize: '0.6rem', color: 'var(--muted)', textTransform: 'uppercase', marginBottom: '0.6rem', letterSpacing: '0.05em' }}>Simulated Power</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{hashrate.toFixed(1)} EH</div>
            <div style={{ fontSize: '0.5rem', color: 'var(--muted)', marginTop: '0.3rem', fontWeight: 600 }}>SU(3) QUANTUM UNIT</div>
          </div>
        </div>
      </div>

      {/* Coptic Terminal */}
      <div style={{ 
        height: '140px', 
        background: 'rgba(0, 0, 0, 0.4)', 
        border: '1px solid var(--border)', 
        borderRadius: '12px', 
        marginTop: '1.5rem',
        padding: '1rem',
        overflow: 'hidden',
        fontFamily: '"JetBrains Mono", monospace',
        fontSize: '0.65rem',
        color: 'rgba(0, 229, 153, 0.7)',
        zIndex: 1,
        backdropFilter: 'blur(10px)'
      }}>
        <div style={{ marginBottom: '0.6rem', color: '#fff', fontWeight: 600, fontSize: '0.55rem', textTransform: 'uppercase', opacity: 0.5 }}>
          Real-time Coptic CIS Instruction Stream
        </div>
        <div style={{ display: 'flex', flexDirection: 'column-reverse' }}>
          {logs.map((log, i) => (
            <div key={i} style={{ marginBottom: '0.2rem', display: 'flex', gap: '0.8rem' }}>
              <span style={{ color: 'var(--text)', opacity: 0.3, flexShrink: 0 }}>{new Date().toLocaleTimeString().split(' ')[0]}</span> 
              <span style={{ color: i === 0 ? 'var(--accent)' : 'inherit' }}>{log}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Start Button */}
      <div style={{ marginTop: '2rem', zIndex: 1 }}>
        <button 
          onClick={() => setIsMining(!isMining)}
          className={`btn ${isMining ? 'secondary' : ''}`}
          style={{ 
            width: '100%', 
            padding: '1.2rem', 
            borderRadius: '16px', 
            fontSize: '1rem', 
            fontWeight: 700, 
            letterSpacing: '0.1em',
            boxShadow: isMining ? 'none' : '0 0 30px rgba(0, 229, 153, 0.3)',
            transition: 'all 0.3s'
          }}
        >
          {isMining ? 'SUSPEND SINGULARITY' : 'BOOT SU(3) MINER'}
        </button>
      </div>

      <div style={{ textAlign: 'center', marginTop: '1.5rem', fontSize: '0.65rem', color: 'rgba(255,255,255,0.3)', letterSpacing: '0.05em' }}>
        Hardware Truth: φ² + 1/φ² = 3.0000
      </div>
    </div>
  );
}
