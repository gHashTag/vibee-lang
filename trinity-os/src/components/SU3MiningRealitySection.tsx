"use client";
import { useEffect, useState, useRef } from 'react';
import { motion } from 'framer-motion';
import { useI18n } from '../i18n/context';
import Section from './Section';

const COPTIC_CHARS = "ⲁⲃⲅⲇⲉⲋⲍⲏⲑⲓⲕⲗⲙⲛⲝⲟⲡⲣⲥⲧⲩⲫⲭⲱϣϥϧϩϫϭϯ";

export default function SU3MiningRealitySection() {
  const { t } = useI18n();
  const reality = t.su3reality;

  const [stats, setStats] = useState({
    block: 0,
    diff: '...',
    efficiency: 578.8,
    hash: 533.7,
    balance: 0
  });

  const [logs, setLogs] = useState<string[]>(reality.logInit || []);
  const logEndRef = useRef<HTMLDivElement>(null);

  // Real-time Telemetry Loop
  useEffect(() => {
    async function fetchNetworkStats() {
      try {
        const walletAddr = 'bc1qgcmea6cr8mzqa5k0rhmz5zc6p0vq5epu873xcf';
        const [blockRes, diffRes, balRes] = await Promise.all([
          fetch('https://blockchain.info/q/getblockcount'),
          fetch('https://blockchain.info/q/difficulty'),
          fetch(`https://blockchain.info/q/addressbalance/${walletAddr}`)
        ]);
        
        const block = await blockRes.json();
        const diffRaw = await diffRes.json();
        const balSat = await balRes.json();
        
        // Convert difficulty to readable 'T' format
        const diffT = (diffRaw / 1e12).toFixed(1) + 'T';
        const balBTC = balSat / 1e8;

        setStats(prev => ({
          ...prev,
          block: block,
          diff: diffT,
          balance: balBTC
        }));
      } catch (err) {
        console.error("Failed to fetch real-time mining/wallet data:", err);
      }
    }

    fetchNetworkStats();
    const networkInterval = setInterval(fetchNetworkStats, 60000); // Update every minute
    return () => clearInterval(networkInterval);
  }, []);

  // Hardware Resonance Simulation (High-Fidelity)
  useEffect(() => {
    const hardwareInterval = setInterval(() => {
      setStats(prev => ({
        ...prev,
        efficiency: Number((578.8 + (Math.random() * 0.4 - 0.2)).toFixed(1)),
        hash: Number((533.7 + (Math.random() * 2 - 1)).toFixed(1)),
      }));

      // Generate Coptic Logic Logs
      const opcodes = ["LD_SU3", "MOV_TRIT", "RESONATE", "HARVEST", "CIS_TX", "PHASE_SHIFT"];
      const op = opcodes[Math.floor(Math.random() * opcodes.length)];
      const char = COPTIC_CHARS[Math.floor(Math.random() * COPTIC_CHARS.length)];
      setLogs(prev => [...prev.slice(-10), `${op}: ${char}${char} ${reality.logSuffix}`]);
    }, 2000);

    return () => clearInterval(hardwareInterval);
  }, []);

  // Auto-scroll logs
  useEffect(() => {
    logEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [logs]);

  if (!reality) return null;

  return (
    <Section id="su3-reality">
      <div className="tight fade" style={{ textAlign: 'center', marginBottom: '4rem' }}>
        <h2 dangerouslySetInnerHTML={{ __html: reality.title }} />
        <p style={{ color: 'var(--muted)', fontSize: '1.1rem' }}>{reality.sub}</p>
      </div>

      <div className="fade" style={{
        maxWidth: '800px',
        margin: '0 auto',
        background: 'rgba(10, 10, 10, 0.8)',
        border: '1px solid rgba(0, 229, 153, 0.3)',
        borderRadius: '24px',
        padding: '2.5rem',
        position: 'relative',
        overflow: 'hidden',
        boxShadow: '0 0 60px rgba(0, 229, 153, 0.15)',
        backdropFilter: 'blur(10px)'
      }}>
        {/* Header Indicator */}
        <div style={{
          background: 'rgba(0, 163, 224, 0.15)',
          border: '1px solid #00A3E0',
          borderRadius: '4px',
          padding: '0.5rem 1.2rem',
          fontSize: '0.75rem',
          fontWeight: '700',
          color: '#00A3E0',
          textAlign: 'center',
          letterSpacing: '0.08em',
          marginBottom: '2.5rem',
          textTransform: 'uppercase'
        }}>
          {reality.mode}
        </div>

        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', 
          gap: '1.5rem', 
          marginBottom: '2.5rem' 
        }}>
          {/* Wallet Info (REAL DATA) */}
          <div style={{
            background: 'rgba(255,255,255,0.02)',
            border: '1px solid rgba(0, 229, 153, 0.15)',
            borderRadius: '16px',
            padding: '1.2rem',
            textAlign: 'left'
          }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.12em', marginBottom: '0.4rem' }}>
              {reality.wallet}
            </div>
            <div style={{ fontSize: '0.85rem', fontWeight: '800', color: '#fff', letterSpacing: '0.05em', fontFamily: 'monospace', wordBreak: 'break-all', marginBottom: '0.5rem' }}>
              {reality.ledger}
            </div>
            <div style={{ fontSize: '1.1rem', fontWeight: '700', color: 'var(--accent)' }}>
              ₿ {stats.balance.toFixed(8)}
            </div>
          </div>

          {/* Network Target (REAL DATA) */}
          <div style={{ textAlign: 'right', background: 'rgba(255,255,255,0.01)', padding: '1.2rem', borderRadius: '16px' }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.12em', marginBottom: '0.4rem' }}>
              {reality.target}
            </div>
            <div style={{ fontSize: '1.1rem', fontWeight: '800', color: '#fff' }}>
              #{stats.block === 0 ? reality.loading : stats.block.toLocaleString()}
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--accent)', fontWeight: 600, marginTop: '0.3rem' }}>
              {reality.diff}: {stats.diff}
            </div>
          </div>
        </div>

        {/* Central SU(3) Core Resonance */}
        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', margin: '3rem 0' }}>
          <div style={{ position: 'relative' }}>
            <motion.div
              animate={{ opacity: [0.2, 0.4, 0.2], scale: [1, 1.05, 1] }}
              transition={{ duration: 3, repeat: Infinity }}
              style={{
                position: 'absolute',
                top: '-30px', left: '-30px', right: '-30px', bottom: '-30px',
                background: 'radial-gradient(circle, rgba(0, 229, 153, 0.25) 0%, transparent 75%)',
                zIndex: 0
              }}
            />
            
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ duration: 15, repeat: Infinity, ease: "linear" }}
              style={{
                width: '240px',
                height: '240px',
                borderRadius: '50%',
                border: '4px double #00E599',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'center',
                alignItems: 'center',
                background: 'rgba(0,0,0,0.9)',
                zIndex: 1,
                position: 'relative',
                boxShadow: '0 0 40px rgba(0, 229, 153, 0.3)',
                padding: '1rem'
              }}
            >
              <div style={{ fontSize: '0.65rem', fontWeight: '800', color: 'rgba(255,255,255,0.5)', letterSpacing: '0.2em', marginBottom: '0.8rem' }}>{reality.coreLabel}</div>
              <div style={{ fontSize: '3.5rem', fontWeight: '900', color: '#00E599', lineHeight: 1 }}>SU(3)</div>
              <div style={{ fontSize: '0.6rem', color: 'var(--accent)', marginTop: '0.8rem', opacity: 0.8 }}>{reality.phaseLocked}</div>
            </motion.div>
          </div>
        </div>

        {/* Coptic Terminal (Instruction Bridge) */}
        <div style={{ 
          background: 'rgba(0,0,0,0.6)', 
          border: '1px solid rgba(0, 229, 153, 0.2)', 
          borderRadius: '12px', 
          marginBottom: '2.5rem',
          padding: '1rem',
          position: 'relative',
          overflow: 'hidden',
          fontFamily: '"JetBrains Mono", monospace',
          boxShadow: 'inset 0 0 20px rgba(0, 229, 153, 0.05)'
        }}>
          <div style={{ marginBottom: '0.8rem', color: '#00E599', fontWeight: '800', fontSize: '0.55rem', textTransform: 'uppercase', opacity: 0.6, letterSpacing: '0.1em' }}>
            {reality.terminalTitle}
          </div>
          <div style={{ 
            height: '100px', 
            overflow: 'hidden',
            fontSize: '0.65rem',
            display: 'flex', 
            flexDirection: 'column-reverse'
          }}>
            <div ref={logEndRef} />
            {logs.map((log, i) => (
              <div key={i} style={{ marginBottom: '0.2rem', color: i === logs.length - 1 ? 'var(--accent)' : 'rgba(255,255,255,0.4)' }}>
                <span style={{ opacity: 0.3, marginRight: '10px' }}>[{new Date().toLocaleTimeString()}]</span>
                {log}
              </div>
            ))}
          </div>
        </div>

        {/* Bottom Efficiency/Performance Metrics */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.2rem' }}>
          <div style={{
            border: '2px solid #00E599',
            borderRadius: '16px',
            padding: '1.2rem',
            textAlign: 'center',
            background: 'rgba(0, 229, 153, 0.05)'
          }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.5rem' }}>
              {reality.efficiency}
            </div>
            <div style={{ fontSize: '2.2rem', fontWeight: '800', color: '#00E599' }}>
               {stats.efficiency.toFixed(1)}x
            </div>
            <div style={{ fontSize: '0.6rem', color: '#00E599', fontWeight: '700', marginTop: '0.5rem' }}>
              {reality.active}
            </div>
          </div>

          <div style={{
            background: 'rgba(255,255,255,0.02)',
            border: '1px solid rgba(255,255,255,0.1)',
            borderRadius: '16px',
            padding: '1.2rem',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.5rem' }}>
              {reality.hash}
            </div>
            <div style={{ fontSize: '2.2rem', fontWeight: '800', color: '#fff' }}>
              {stats.hash.toFixed(1)} EH
            </div>
            <div style={{ fontSize: '0.6rem', color: 'rgba(255,255,255,0.3)', marginTop: '0.5rem' }}>
              {reality.pulse}
            </div>
          </div>
        </div>

        {/* Investor Proof Section */}
        <div style={{ marginTop: '4rem', padding: '2rem', borderTop: '1px solid rgba(0, 229, 153, 0.1)' }}>
          <div style={{ textAlign: 'left', marginBottom: '2.5rem' }}>
            <h3 style={{ fontSize: '1.2rem', color: 'var(--accent)', marginBottom: '1rem' }}>{reality.proofTitle}</h3>
            <p style={{ fontSize: '0.9rem', lineHeight: '1.6', color: 'rgba(255,255,255,0.7)', maxWidth: '600px' }}>
              {reality.proofIntro}
            </p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1.5rem' }}>
            {reality.proofItems?.map((item: any, i: number) => (
              <div key={i} style={{ 
                background: 'rgba(255,255,255,0.02)', 
                padding: '1.2rem', 
                borderRadius: '12px', 
                borderLeft: '2px solid var(--accent)' 
              }}>
                <h4 style={{ fontSize: '0.9rem', marginBottom: '0.6rem', color: '#fff' }}>{item.title}</h4>
                <p style={{ fontSize: '0.75rem', lineHeight: '1.4', color: 'var(--muted)', margin: 0 }}>{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Section>
  );
}
