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
    balance: 0,
    lastSync: '...'
  });

  const [logs, setLogs] = useState<string[]>([]);
  const terminalRef = useRef<HTMLDivElement>(null);

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
        
        const diffT = (diffRaw / 1e12).toFixed(1) + 'T';
        const balBTC = balSat / 1e8;
        const now = new Date().toLocaleTimeString();

        setStats(prev => ({
          ...prev,
          block: block,
          diff: diffT,
          balance: balBTC,
          lastSync: now
        }));

        setLogs(prev => {
          const newLogs = [...prev.slice(-10), `[API_AUTO_CHECK] Verified ${walletAddr}: ${balBTC.toFixed(8)} BTC` + (balBTC === 0 ? " (Empty Wallet)" : "")];
          return newLogs;
        });
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

  // Fixed Auto-scroll (local only, no page jumps)
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [logs]);

  // Ensure logs are initialized without triggering layout shift if possible
  useEffect(() => {
    if (reality.logInit) setLogs(reality.logInit);
  }, [reality.logInit]);

  if (!reality) return null;

  return (
    <Section id="su3-reality" style={{ maxWidth: '100%', width: '100%', paddingLeft: '5%', paddingRight: '5%' }}>
      <div style={{ textAlign: 'center', marginBottom: '1rem', width: '100%' }}>
        <h2 style={{ marginBottom: '0.4rem', fontSize: '1.4rem' }} dangerouslySetInnerHTML={{ __html: reality.title }} />
        <p style={{ color: 'var(--muted)', fontSize: '0.8rem' }}>{reality.sub}</p>
      </div>

      <div style={{
        width: '100%',
        background: 'rgba(10, 10, 10, 0.95)',
        borderTop: '1px solid rgba(0, 229, 153, 0.3)',
        borderBottom: '1px solid rgba(0, 229, 153, 0.3)',
        padding: '1rem',
        position: 'relative',
        boxShadow: '0 0 40px rgba(0, 229, 153, 0.05)',
        backdropFilter: 'blur(10px)',
        minHeight: '320px'
      }}>
        {/* Header Indicator */}
        <div style={{
          background: 'rgba(0, 163, 224, 0.08)',
          border: '1px solid #00A3E0',
          borderRadius: '4px',
          padding: '0.3rem 0.8rem',
          fontSize: '0.6rem',
          fontWeight: '700',
          color: '#00A3E0',
          textAlign: 'center',
          letterSpacing: '0.05em',
          marginBottom: '1rem',
          textTransform: 'uppercase'
        }}>
          {reality.mode} [SYNCED: {stats.lastSync}]
        </div>

        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', 
          gap: '1rem', 
          marginBottom: '1rem' 
        }}>
          {/* Wallet Info (REAL DATA) */}
          <div style={{
            background: 'rgba(255,255,255,0.01)',
            borderLeft: '2px solid rgba(0, 229, 153, 0.4)',
            padding: '0.8rem',
            textAlign: 'left',
            minHeight: '80px'
          }}>
            <div style={{ fontSize: '0.55rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.2rem' }}>
              {reality.wallet}
            </div>
            <div style={{ fontSize: '0.7rem', fontWeight: '800', color: '#fff', letterSpacing: '0.05em', fontFamily: 'monospace', wordBreak: 'break-all', marginBottom: '0.3rem' }}>
              {reality.ledger}
            </div>
            <div style={{ fontSize: '1.1rem', fontWeight: '700', color: 'var(--accent)', lineHeight: 1 }}>
              ₿ {stats.balance.toFixed(8)}
            </div>
          </div>

          {/* Network Target (REAL DATA) */}
          <div style={{ textAlign: 'right', background: 'rgba(255,255,255,0.01)', padding: '0.8rem', minHeight: '80px' }}>
            <div style={{ fontSize: '0.55rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.2rem' }}>
              {reality.target}
            </div>
            <div style={{ fontSize: '1.1rem', fontWeight: '800', color: '#fff', lineHeight: 1 }}>
              #{stats.block === 0 ? reality.loading : stats.block.toLocaleString()}
            </div>
            <div style={{ fontSize: '0.65rem', color: 'var(--accent)', fontWeight: 600, marginTop: '0.3rem' }}>
              {reality.diff}: {stats.diff}
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', margin: '0.8rem 0' }}>
          <div style={{ position: 'relative' }}>
            <motion.div
              animate={{ opacity: [0.1, 0.2, 0.1], scale: [1, 1.05, 1] }}
              transition={{ duration: 3, repeat: Infinity }}
              style={{
                position: 'absolute',
                top: '-10px', left: '-10px', right: '-10px', bottom: '-10px',
                background: 'radial-gradient(circle, rgba(0, 229, 153, 0.1) 0%, transparent 75%)',
                zIndex: 0
              }}
            />
            
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ duration: 25, repeat: Infinity, ease: "linear" }}
              style={{
                width: '110px',
                height: '110px',
                borderRadius: '50%',
                border: '1.5px double #00E599',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'center',
                alignItems: 'center',
                background: 'rgba(0,0,0,0.98)',
                zIndex: 1,
                position: 'relative',
                boxShadow: '0 0 15px rgba(0, 229, 153, 0.05)',
                padding: '0.4rem'
              }}
            >
              <div style={{ fontSize: '0.45rem', fontWeight: '800', color: 'rgba(255,255,255,0.4)', letterSpacing: '0.1em', marginBottom: '0.2rem' }}>{reality.coreLabel}</div>
              <div style={{ fontSize: '1.8rem', fontWeight: '900', color: '#00E599', lineHeight: 1 }}>SU(3)</div>
              <div style={{ fontSize: '0.4rem', color: 'var(--accent)', marginTop: '0.3rem', opacity: 0.6 }}>{reality.phaseLocked}</div>
            </motion.div>
          </div>
        </div>

        <div style={{ 
          background: 'rgba(0,0,0,0.7)', 
          border: '1px solid rgba(0, 229, 153, 0.15)', 
          borderRadius: '8px', 
          marginBottom: '1rem',
          padding: '0.6rem',
          position: 'relative',
          overflow: 'hidden',
          fontFamily: '"JetBrains Mono", monospace'
        }}>
          <div style={{ marginBottom: '0.4rem', color: '#00E599', fontWeight: '800', fontSize: '0.45rem', textTransform: 'uppercase', opacity: 0.5, letterSpacing: '0.1em' }}>
            {reality.terminalTitle}
          </div>
          <div 
            ref={terminalRef}
            style={{ 
              height: '60px', 
              overflowY: 'auto',
              fontSize: '0.55rem',
              display: 'flex', 
              flexDirection: 'column',
              scrollbarWidth: 'none', /* Firefox */
              msOverflowStyle: 'none'  /* IE/Edge */
            }}
          >
            {/* Standard scrollbar hiding for Chrome/Safari */}
            <style dangerouslySetInnerHTML={{ __html: `
              div::-webkit-scrollbar { display: none; }
            `}} />
            {logs.map((log, i) => (
              <div key={i} style={{ marginBottom: '0.1rem', color: i === logs.length - 1 ? 'var(--accent)' : 'rgba(255,255,255,0.3)' }}>
                <span style={{ opacity: 0.2, marginRight: '6px' }}>[{new Date().toLocaleTimeString()}]</span>
                {log}
              </div>
            ))}
          </div>
        </div>

        {/* Bottom Efficiency/Performance Metrics */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.8rem' }}>
          <div style={{
            border: '1.5px solid #00E599',
            borderRadius: '12px',
            padding: '0.8rem',
            textAlign: 'center',
            background: 'rgba(0, 229, 153, 0.03)'
          }}>
            <div style={{ fontSize: '0.55rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.3rem' }}>
              {reality.efficiency}
            </div>
            <div style={{ fontSize: '1.5rem', fontWeight: '800', color: '#00E599' }}>
               {stats.efficiency.toFixed(1)}x
            </div>
            <div style={{ fontSize: '0.5rem', color: '#00E599', fontWeight: '700', marginTop: '0.3rem' }}>
              {reality.active}
            </div>
          </div>

          <div style={{
            background: 'rgba(255,255,255,0.01)',
            border: '1px solid rgba(255,255,255,0.05)',
            borderRadius: '12px',
            padding: '0.8rem',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.55rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.3rem' }}>
              {reality.hash}
            </div>
            <div style={{ fontSize: '1.5rem', fontWeight: '800', color: '#fff' }}>
              {stats.hash.toFixed(1)} EH
            </div>
            <div style={{ fontSize: '0.5rem', color: 'rgba(255,255,255,0.3)', marginTop: '0.3rem' }}>
              {reality.pulse}
            </div>
          </div>
        </div>

        {/* Investor Proof Section */}
        <div style={{ marginTop: '2.5rem', padding: '1.5rem 0 0 0', borderTop: '1px solid rgba(0, 229, 153, 0.1)' }}>
          <div style={{ textAlign: 'left', marginBottom: '1.5rem' }}>
            <h3 style={{ fontSize: '1rem', color: 'var(--accent)', marginBottom: '0.6rem' }}>{reality.proofTitle}</h3>
            <p style={{ fontSize: '0.8rem', lineHeight: '1.5', color: 'rgba(255,255,255,0.7)', maxWidth: 'none' }}>
              {reality.proofIntro}
            </p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem' }}>
            {reality.proofItems?.map((item: any, i: number) => (
              <div key={i} style={{ 
                background: 'rgba(255,255,255,0.02)', 
                padding: '1rem', 
                borderRadius: '10px', 
                borderLeft: '2px solid var(--accent)' 
              }}>
                <h4 style={{ fontSize: '0.8rem', marginBottom: '0.4rem', color: '#fff' }}>{item.title}</h4>
                <p style={{ fontSize: '0.7rem', lineHeight: '1.4', color: 'var(--muted)', margin: 0 }}>{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Section>
  );
}
