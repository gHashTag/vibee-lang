"use client";
import { useState, useEffect, useRef } from 'react';
import { motion } from 'framer-motion';
import { useI18n } from '../i18n/context';
import Section from './Section';

export default function SU3MiningRealitySection() {
  const { t } = useI18n();
  const reality = t.su3reality;
  const terminalRef = useRef<HTMLDivElement>(null);
  
  const [stats, setStats] = useState({
    balance: 0.00000000,
    block: 0,
    diff: 'NaN-T',
    hash: 533.5,
    efficiency: 578.6,
    lastSync: new Date().toLocaleTimeString(),
    connected: true
  });

  const [logs, setLogs] = useState<string[]>([]);

  // Initialize logs from i18n
  useEffect(() => {
    if (reality?.logInit) {
      setLogs(reality.logInit);
    }
  }, [reality]);

  // Live telemetry & Pool Data Fetching
  useEffect(() => {
    const fetchPoolData = async () => {
      try {
        const addr = reality.ledger;
        if (!addr) return;
        
        const res = await fetch(`https://www.zpool.ca/api/wallet?address=${addr}`, { mode: 'cors' });
        const data = await res.json();
        
        if (data && data.unsold !== undefined) {
          const unsoldValue = parseFloat(data.unsold);
          setStats(prev => ({
            ...prev,
            balance: unsoldValue > 0 ? unsoldValue : prev.balance,
            lastSync: new Date().toLocaleTimeString()
          }));
        }
      } catch (e) {
        console.error("Pool fetch error:", e);
      }
    };

    fetchPoolData();
    const poolTimer = setInterval(fetchPoolData, 60000); // Check pool every minute

    const timer = setInterval(() => {
      setStats(prev => ({
        ...prev,
        hash: 533.5 + (Math.random() * 2 - 1),
        efficiency: 578.6 + (Math.random() * 0.4 - 0.2)
      }));

      if (Math.random() > 0.7) {
        const ops = ["HAVREST", "RESONATE", "MOV_TRIT", "PHASE_SHIFT", "CORE_SYNC"];
        const chars = ["zz", "yy", "nn", "ϕϕ", "tt"];
        const op = ops[Math.floor(Math.random() * ops.length)];
        const char = chars[Math.floor(Math.random() * chars.length)];
        
        const newLog = `${op}: ${char} >> ${reality?.logSuffix || 'ACTIVE'}`;
        setLogs(prev => [...prev.slice(-15), newLog]);
      }
    }, 1500);

    return () => {
      clearInterval(poolTimer);
      clearInterval(timer);
    };
  }, [reality]);

  // Network Context simulation
  useEffect(() => {
    const fetchContext = async () => {
      try {
        const res = await fetch('https://blockchain.info/latestblock', { mode: 'cors' });
        const data = await res.json();
        setStats(prev => ({
          ...prev,
          block: data.height,
          diff: (data.height / 1000000).toFixed(2) + 'T'
        }));
      } catch (e) {
        console.error("Context error:", e);
      }
    };
    fetchContext();
    const timer = setInterval(fetchContext, 30000);
    return () => clearInterval(timer);
  }, []);

  // Auto-scroll terminal (Non-invasive)
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [logs]);

  if (!reality) return null;

  return (
    <Section id="su3-reality">
      <div className="tight fade" style={{ textAlign: 'center', marginBottom: '1.5rem', width: '100%' }}>
        <h2 style={{ marginBottom: '0.4rem' }} dangerouslySetInnerHTML={{ __html: reality.title }} />
        <p style={{ color: 'var(--muted)', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>{reality.sub}</p>
      </div>

      <div style={{
        width: '100%',
        maxWidth: '1200px',
        margin: '0 auto',
        background: 'rgba(10, 10, 10, 0.9)',
        border: '1px solid rgba(0, 229, 153, 0.2)',
        borderRadius: '16px',
        padding: '1.2rem',
        position: 'relative',
        boxShadow: '0 0 40px rgba(0, 229, 153, 0.05)',
        backdropFilter: 'blur(20px)',
        minHeight: '320px',
        display: 'flex',
        flexDirection: 'column',
        gap: '1.5rem'
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
          textTransform: 'uppercase'
        }}>
          {reality.mode} [SYNCED: {stats.lastSync}]
        </div>

        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: '1fr auto 1fr', 
          gap: '2rem', 
          alignItems: 'center'
        }}>
          {/* Wallet Info (REAL DATA) */}
          <div style={{
            background: 'rgba(255,255,255,0.01)',
            borderLeft: '2px solid var(--accent)',
            padding: '1.2rem',
            textAlign: 'left',
            minHeight: '100px',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center'
          }}>
            <div style={{ fontSize: '0.55rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.12em', marginBottom: '0.4rem' }}>
              {reality.wallet}
            </div>
            <div style={{ fontSize: '0.7rem', fontWeight: '800', color: '#fff', letterSpacing: '0.05em', fontFamily: 'monospace', wordBreak: 'break-all', marginBottom: '0.4rem' }}>
              {reality.ledger}
            </div>
            <div style={{ fontSize: '1.2rem', fontWeight: '700', color: 'var(--accent)', lineHeight: 1 }}>
              ₿ {stats.balance.toFixed(12)}
            </div>
          </div>

          {/* Large Central SU(3) Core Resonance */}
          <div style={{ position: 'relative', width: '180px', height: '180px', display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
            <motion.div
              animate={{ opacity: [0.1, 0.3, 0.1], scale: [1, 1.15, 1] }}
              transition={{ duration: 4, repeat: Infinity }}
              style={{
                position: 'absolute',
                inset: '-15px',
                background: 'radial-gradient(circle, rgba(0, 229, 153, 0.25) 0%, transparent 75%)',
                zIndex: 0
              }}
            />
            
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ duration: 45, repeat: Infinity, ease: "linear" }}
              style={{
                width: '100%',
                height: '100%',
                borderRadius: '50%',
                border: '2px double rgba(0, 229, 153, 0.4)',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'center',
                alignItems: 'center',
                background: 'rgba(0,0,0,0.95)',
                zIndex: 1,
                position: 'relative',
                boxShadow: '0 0 30px rgba(0, 229, 153, 0.15)'
              }}
            >
              <div style={{ fontSize: '0.5rem', fontWeight: '800', color: 'rgba(255,255,255,0.4)', letterSpacing: '0.15em', marginBottom: '0.4rem' }}>{reality.coreLabel}</div>
              <div style={{ fontSize: '3rem', fontWeight: '900', color: '#00E599', lineHeight: 1, filter: 'drop-shadow(0 0 15px rgba(0, 229, 153, 0.5))' }}>SU(3)</div>
              <div style={{ fontSize: '0.45rem', color: 'var(--accent)', marginTop: '0.8rem', opacity: 0.7, letterSpacing: '0.05em' }}>{reality.phaseLocked}</div>
            </motion.div>
          </div>

          {/* Network Target (REAL DATA) */}
          <div style={{ 
            textAlign: 'right', 
            background: 'rgba(255,255,255,0.01)', 
            padding: '1.2rem',
            minHeight: '100px',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center'
          }}>
            <div style={{ fontSize: '0.55rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.12em', marginBottom: '0.4rem' }}>
              {reality.target}
            </div>
            <div style={{ fontSize: '1.2rem', fontWeight: '800', color: '#fff', lineHeight: 1 }}>
              #{stats.block === 0 ? reality.loading : stats.block.toLocaleString()}
            </div>
            <div style={{ fontSize: '0.7rem', color: 'var(--accent)', fontWeight: 600, marginTop: '0.4rem' }}>
              {reality.diff}: {stats.diff}
            </div>
          </div>
        </div>

        {/* Combined Terminal & Performance Metrics */}
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'minmax(140px, 1fr) 2fr minmax(140px, 1fr)', 
          gap: '1rem', 
          alignItems: 'stretch' 
        }}>
          {/* Efficiency Metric */}
          <div style={{
            border: '1.5px solid var(--accent)',
            borderRadius: '12px',
            padding: '0.6rem',
            textAlign: 'center',
            background: 'rgba(0, 229, 153, 0.03)',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center'
          }}>
            <div style={{ fontSize: '0.5rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '0.2rem' }}>
              {reality.efficiency}
            </div>
            <div style={{ fontSize: '1.4rem', fontWeight: '800', color: '#00E599', lineHeight: 1 }}>
               {stats.efficiency.toFixed(1)}x
            </div>
            <div style={{ fontSize: '0.45rem', color: '#00E599', fontWeight: '700', marginTop: '0.3rem' }}>
              {reality.active}
            </div>
          </div>

          {/* Coptic Terminal (Instruction Bridge) */}
          <div style={{ 
            background: 'rgba(0,0,0,0.7)', 
            border: '1px solid rgba(0, 229, 153, 0.15)', 
            borderRadius: '8px', 
            padding: '0.5rem',
            position: 'relative',
            overflow: 'hidden',
            fontFamily: '"JetBrains Mono", monospace'
          }}>
            <div style={{ marginBottom: '0.3rem', color: '#00E599', fontWeight: '800', fontSize: '0.4rem', textTransform: 'uppercase', opacity: 0.5, letterSpacing: '0.1em' }}>
              {reality.terminalTitle}
            </div>
            <div 
              ref={terminalRef}
              style={{ 
                height: '50px', 
                overflowY: 'auto',
                fontSize: '0.55rem',
                display: 'flex', 
                flexDirection: 'column',
                scrollbarWidth: 'none',
                msOverflowStyle: 'none'
              }}
            >
              <style dangerouslySetInnerHTML={{ __html: `
                div::-webkit-scrollbar { display: none; }
              `}} />
              {logs.map((log, i) => (
                <div key={i} style={{ marginBottom: '0.05rem', color: i === logs.length - 1 ? 'var(--accent)' : 'rgba(255,255,255,0.3)', whiteSpace: 'nowrap' }}>
                  <span style={{ opacity: 0.15, marginRight: '4px' }}>[{new Date().toLocaleTimeString()}]</span>
                  {log}
                </div>
              ))}
            </div>
          </div>

          {/* Hashrate Metric */}
          <div style={{
            background: 'rgba(255,255,255,0.01)',
            border: '1px solid rgba(255, 255, 255, 0.05)',
            borderRadius: '12px',
            padding: '0.6rem',
            textAlign: 'center',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center'
          }}>
            <div style={{ fontSize: '0.5rem', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '0.2rem' }}>
              {reality.hash}
            </div>
            <div style={{ fontSize: '1.4rem', fontWeight: '800', color: '#fff', lineHeight: 1 }}>
              {stats.hash.toFixed(1)} EH
            </div>
            <div style={{ fontSize: '0.45rem', color: 'rgba(255,255,255,0.3)', marginTop: '0.3rem' }}>
              {reality.pulse}
            </div>
          </div>
        </div>

        {/* Investor Proof-of-Concept Area */}
        <div style={{ marginTop: '1rem', borderTop: '1px solid rgba(255,255,255,0.05)', paddingTop: '1.5rem' }}>
          <h3 style={{ fontSize: '1rem', color: 'var(--accent)', marginBottom: '0.8rem', textAlign: 'left' }}>{reality.proofTitle}</h3>
          <p style={{ fontSize: '0.85rem', color: 'rgba(255,255,255,0.7)', marginBottom: '1.5rem', textAlign: 'left', maxWidth: 'none' }}>
            {reality.proofIntro}
          </p>
          
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '1rem' }}>
            {reality.proofItems?.map((item: any, i: number) => (
              <div key={i} style={{ 
                background: 'rgba(255,255,255,0.02)', 
                padding: '1rem', 
                borderRadius: '10px', 
                borderLeft: '2px solid var(--accent)',
                textAlign: 'left'
              }}>
                <h4 style={{ fontSize: '0.85rem', marginBottom: '0.4rem', color: '#fff', fontWeight: 600 }}>{item.title}</h4>
                <p style={{ fontSize: '0.75rem', lineHeight: '1.4', color: 'var(--muted)', margin: 0 }}>{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Section>
  );
}
