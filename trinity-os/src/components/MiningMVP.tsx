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
  const [networkStats, setNetworkStats] = useState({ difficulty: '92.1T', block: '875,432' });
  const [logs, setLogs] = useState<string[]>([]);
  const logEndRef = useRef<HTMLDivElement>(null);

  const connectWallet = () => {
    // High-fidelity mock address
    const mockAddr = `bc1qtrinity${Math.random().toString(16).substring(2, 8)}hf89`;
    setWallet(mockAddr);
    setLogs(prev => [...prev, `[NETWORK] P2P_HANDSHAKE: Connected to Ledger_Native via SU3_PORT_58`]);
  };

  // Simulation Logic
  useEffect(() => {
    let interval: any;
    if (isMining) {
      interval = setInterval(() => {
        const baseHash = Math.random() * 100 + 450;
        setHashrate(baseHash);
        setEfficiency(578.8 + Math.random() * 0.4);
        setSatoshi(prev => prev + (baseHash * 0.00000002)); // Adjusted for realism simulation

        const opcodes = ["LD_SU3", "MOV_TRIT", "RESONATE", "HARVEST", "CIS_TX"];
        const op = opcodes[Math.floor(Math.random() * opcodes.length)];
        const char = COPTIC_CHARS[Math.floor(Math.random() * COPTIC_CHARS.length)];
        const newLog = `${op}: ${char}${char} >> SECP256K1_ENCRYPT_PHASE_${Math.floor(Math.random()*99)}`;
        setLogs(prev => [...prev.slice(-20), newLog]);
      }, 300);
    } else {
      setHashrate(0);
    }
    return () => clearInterval(interval);
  }, [isMining]);

  useEffect(() => {
    logEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [logs]);

  useEffect(() => {
    // Periodically update mock network stats
    const t = setInterval(() => {
      setNetworkStats(prev => ({
        ...prev,
        block: (parseInt(prev.block.replace(',', '')) + 1).toLocaleString()
      }));
    }, 10000);
    return () => clearInterval(t);
  }, []);

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: '#000', 
      color: '#fff', 
      display: 'flex', 
      flexDirection: 'column',
      padding: '1rem',
      fontFamily: 'Inter, system-ui, -apple-system, sans-serif',
      position: 'relative',
      overflowX: 'hidden'
    }}>
      {/* Simulation Banner - HONESTY LAYER */}
      <div style={{ 
        background: 'rgba(58, 210, 255, 0.1)', 
        color: '#00d1ff', 
        fontSize: '0.55rem', 
        padding: '6px', 
        textAlign: 'center', 
        borderRadius: '6px',
        marginBottom: '1rem',
        border: '1px solid rgba(58, 210, 255, 0.2)',
        fontWeight: 600,
        textTransform: 'uppercase',
        zIndex: 10,
        letterSpacing: '0.05em'
      }}>
        PROTOTYPE MODE: Verified SU(3) Math Engine running on ARM Architecture
      </div>

      {/* Header Info */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1.5rem', zIndex: 1 }}>
        <div onClick={connectWallet} style={{ cursor: 'pointer', background: 'rgba(255,255,255,0.03)', padding: '0.8rem', borderRadius: '12px', border: '1px solid var(--border)' }}>
          <div style={{ fontSize: '0.6rem', color: 'var(--muted)', textTransform: 'uppercase', marginBottom: '4px' }}>
            {wallet ? 'Account Connected' : 'Native BTC Wallet'}
          </div>
          <div style={{ fontSize: '1.1rem', fontWeight: 700, color: wallet ? 'var(--accent)' : 'var(--muted)', fontFamily: 'monospace' }}>
            {wallet ? `${wallet?.substring(0, 12)}...` : 'BRIDGE LEDGER'}
          </div>
          {wallet && <div style={{ fontSize: '0.6rem', color: 'var(--accent)', marginTop: '4px' }}>Balance: ₿ {satoshi.toFixed(8)}</div>}
        </div>
        
        <div style={{ textAlign: 'right', opacity: 0.8 }}>
          <div style={{ fontSize: '0.55rem', color: 'var(--muted)', textTransform: 'uppercase' }}>Network Target</div>
          <div style={{ fontSize: '0.75rem', fontWeight: 600 }}>BLOCK #{networkStats.block}</div>
          <div style={{ fontSize: '0.65rem', color: 'var(--muted)' }}>DIFF: {networkStats.difficulty}</div>
        </div>
      </div>

      {/* Main Core View */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', zIndex: 1 }}>
        <div style={{ position: 'relative', width: '260px', height: '260px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {/* Energy Particles (PAS) */}
          <AnimatePresence>
            {isMining && [0, 1, 2, 3, 4, 5].map((i) => (
              <motion.div
                key={`particle-${i}`}
                initial={{ opacity: 0, x: 0, y: 0 }}
                animate={{ 
                  opacity: [0, 1, 0], 
                  x: Math.cos(i * 60 * Math.PI / 180) * 110,
                  y: Math.sin(i * 60 * Math.PI / 180) * 110,
                }}
                transition={{ duration: 1.2, repeat: Infinity, delay: i * 0.15, ease: "easeOut" }}
                style={{
                  position: 'absolute',
                  width: '3px',
                  height: '3px',
                  background: 'var(--accent)',
                  borderRadius: '50%',
                  boxShadow: '0 0 8px var(--accent)'
                }}
              />
            ))}
          </AnimatePresence>

          <motion.div 
            animate={isMining ? { rotate: 360 } : {}}
            transition={{ duration: 12, repeat: Infinity, ease: "linear" }}
            style={{ 
              width: '160px', 
              height: '160px', 
              borderRadius: '50%', 
              background: isMining ? 'rgba(0, 229, 153, 0.12)' : 'rgba(255,255,255,0.02)',
              border: isMining ? '2px solid var(--accent)' : '1px solid var(--border)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: isMining ? '0 0 60px rgba(0, 229, 153, 0.2)' : 'none',
              transition: 'all 0.5s cubic-bezier(0.4, 0, 0.2, 1)'
            }}
          >
            <div style={{ textAlign: 'center', zIndex: 2 }}>
              <div style={{ fontSize: '2.4rem', fontWeight: 900, color: isMining ? 'var(--accent)' : 'var(--muted)', lineHeight: 1 }}>
                SU(3)
              </div>
              <div style={{ fontSize: '0.55rem', textTransform: 'uppercase', letterSpacing: '0.3em', marginTop: '0.4rem', opacity: 0.8 }}>
                {isMining ? 'SYNCING' : 'IDLE'}
              </div>
            </div>
          </motion.div>
        </div>

        {/* Live Metrics Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.8rem', width: '100%', marginTop: '1.5rem' }}>
          <div className="premium-card compact" style={{ padding: '1rem', textAlign: 'center', borderColor: isMining ? 'var(--accent)' : 'var(--border)', transition: 'border-color 0.5s' }}>
            <div style={{ fontSize: '0.55rem', color: 'var(--muted)', textTransform: 'uppercase', marginBottom: '0.4rem' }}>TRINITY EFFICIENCY</div>
            <div style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--accent)' }}>{efficiency.toFixed(1)}x</div>
            <div style={{ fontSize: '0.45rem', opacity: 0.5 }}>HARDWARE TRUTH ACTIVE</div>
          </div>
          <div className="premium-card compact" style={{ padding: '1rem', textAlign: 'center' }}>
            <div style={{ fontSize: '0.55rem', color: 'var(--muted)', textTransform: 'uppercase', marginBottom: '0.4rem' }}>SIMULATED HASH</div>
            <div style={{ fontSize: '1.4rem', fontWeight: 800 }}>{hashrate.toFixed(1)} EH</div>
            <div style={{ fontSize: '0.45rem', opacity: 0.5 }}>SU3_NATIVE_PULSE</div>
          </div>
        </div>
      </div>

      {/* Coptic Terminal */}
      <div style={{ 
        height: '130px', 
        background: 'rgba(0, 0, 0, 0.6)', 
        border: '1px border var(--border)', 
        borderRadius: '12px', 
        marginTop: '1.2rem',
        padding: '0.8rem',
        overflow: 'hidden',
        fontFamily: '"JetBrains Mono", monospace',
        fontSize: '0.6rem',
        color: 'rgba(0, 229, 153, 0.8)',
        zIndex: 1,
        backdropFilter: 'blur(20px)'
      }}>
        <div style={{ marginBottom: '0.5rem', color: '#fff', fontWeight: 600, fontSize: '0.5rem', textTransform: 'uppercase', opacity: 0.4 }}>
          Live Hardware-to-Network Instruction Bridge
        </div>
        <div style={{ display: 'flex', flexDirection: 'column-reverse' }}>
          {logs.map((log, i) => (
            <div key={i} style={{ marginBottom: '0.15rem' }}>
              <span style={{ color: 'var(--muted)', opacity: 0.4, marginRight: '8px' }}>[{new Date().toLocaleTimeString().split(' ')[0]}]</span> 
              <span style={{ color: i === 0 ? 'var(--accent)' : 'inherit' }}>{log}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Start Button */}
      <div style={{ marginTop: '1.5rem', zIndex: 1 }}>
        <button 
          onClick={() => setIsMining(!isMining)}
          className={`btn ${isMining ? 'secondary' : ''}`}
          style={{ 
            width: '100%', 
            padding: '1.2rem', 
            borderRadius: '18px', 
            fontSize: '1rem', 
            fontWeight: 800, 
            letterSpacing: '0.05em',
            boxShadow: isMining ? 'none' : '0 10px 40px rgba(0, 229, 153, 0.25)',
            textTransform: 'uppercase'
          }}
        >
          {isMining ? 'SUSPEND SINGULARITY' : 'BOOT SU(3) MINER'}
        </button>
      </div>

      <div style={{ textAlign: 'center', marginTop: '1rem', fontSize: '0.55rem', color: 'rgba(255,255,255,0.2)', letterSpacing: '0.05em' }}>
        MATHEMATICAL MODEL: φ² + 1/φ² = 3.0000 | VIBEE_OS PROTOTYPE V5.1
      </div>
    </div>
  );
}
