"use client";
import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { useI18n } from '../i18n/context';
import Section from './Section';

export default function SU3MiningRealitySection() {
  const { t } = useI18n();
  const reality = t.su3reality;

  const [stats, setStats] = useState({
    block: 876194,
    diff: '92.1T',
    efficiency: 579.2,
    hash: 533.7,
  });

  // Simulated live updates
  useEffect(() => {
    const interval = setInterval(() => {
      setStats(prev => ({
        ...prev,
        block: Math.random() > 0.95 ? prev.block + 1 : prev.block,
        efficiency: Number((prev.efficiency + (Math.random() * 0.4 - 0.2)).toFixed(1)),
        hash: Number((prev.hash + (Math.random() * 2 - 1)).toFixed(1)),
      }));
    }, 3000);
    return () => clearInterval(interval);
  }, []);

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
        background: 'rgba(0,0,0,0.4)',
        border: '1px solid rgba(0, 229, 153, 0.2)',
        borderRadius: '24px',
        padding: '2rem',
        position: 'relative',
        overflow: 'hidden',
        boxShadow: '0 0 50px rgba(0, 229, 153, 0.1)'
      }}>
        {/* Header Indicator */}
        <div style={{
          background: 'rgba(0, 163, 224, 0.1)',
          border: '1px solid #00A3E0',
          borderRadius: '4px',
          padding: '0.4rem 1rem',
          fontSize: '0.7rem',
          fontWeight: '700',
          color: '#00A3E0',
          textAlign: 'center',
          letterSpacing: '0.05em',
          marginBottom: '2rem'
        }}>
          {reality.mode}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem', marginBottom: '3rem' }}>
          {/* Wallet Info */}
          <div style={{
            background: 'rgba(255,255,255,0.03)',
            border: '1px solid rgba(255,255,255,0.1)',
            borderRadius: '12px',
            padding: '1.5rem',
          }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', letterSpacing: '0.1em', marginBottom: '0.5rem' }}>
              {reality.wallet}
            </div>
            <div style={{ fontSize: '1.5rem', fontWeight: '800', color: '#fff', letterSpacing: '0.05em' }}>
              {reality.ledger}
            </div>
          </div>

          {/* Network Target */}
          <div style={{ textAlign: 'right' }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', letterSpacing: '0.1em', marginBottom: '0.5rem' }}>
              {reality.target}
            </div>
            <div style={{ fontSize: '1.2rem', fontWeight: '700', color: '#fff' }}>
              {reality.block}{stats.block.toLocaleString()}
            </div>
            <div style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.4)' }}>
              {reality.diff}: {stats.diff}
            </div>
          </div>
        </div>

        {/* Central SU(3) Pulse */}
        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', margin: '4rem 0' }}>
          <div style={{ position: 'relative' }}>
            {/* Outer Glows */}
            <motion.div
              animate={{ opacity: [0.1, 0.3, 0.1], scale: [1, 1.1, 1] }}
              transition={{ duration: 4, repeat: Infinity }}
              style={{
                position: 'absolute',
                top: '-20px', left: '-20px', right: '-20px', bottom: '-20px',
                background: 'radial-gradient(circle, rgba(0, 229, 153, 0.2) 0%, transparent 70%)',
                zIndex: 0
              }}
            />
            
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
              style={{
                width: '280px',
                height: '280px',
                borderRadius: '50%',
                border: '3px solid #00E599',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'center',
                alignItems: 'center',
                background: 'rgba(0,0,0,0.8)',
                zIndex: 1,
                position: 'relative',
                boxShadow: '0 0 30px rgba(0, 229, 153, 0.4), inset 0 0 20px rgba(0, 229, 153, 0.2)'
              }}
            >
              <div style={{ 
                fontSize: '0.7rem', 
                fontWeight: '700', 
                color: 'rgba(255,255,255,0.6)', 
                letterSpacing: '0.3em', 
                marginBottom: '0.5rem',
                transform: 'rotate(180deg)'
              }}>
                SINGULARITY
              </div>
              <div style={{ fontSize: '4rem', fontWeight: '900', color: '#00E599', transform: 'rotate(180deg)' }}>
                SU(3)
              </div>
            </motion.div>
          </div>
        </div>

        {/* Bottom Metrics */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
          <div style={{
            border: '2px solid #00E599',
            borderRadius: '16px',
            padding: '1.5rem',
            textAlign: 'center',
            background: 'rgba(0, 229, 153, 0.03)'
          }}>
            <div style={{ fontSize: '0.6rem', color: 'rgba(255,255,255,0.4)', letterSpacing: '0.15em', marginBottom: '0.5rem' }}>
              {reality.efficiency}
            </div>
            <div style={{ fontSize: '2.5rem', fontWeight: '800', color: '#00E599' }}>
               {stats.efficiency.toFixed(1)}x
            </div>
            <div style={{ fontSize: '0.55rem', color: '#00E599', fontWeight: '700', letterSpacing: '0.05em', marginTop: '0.5rem' }}>
              {reality.active}
            </div>
          </div>

          <div style={{
            background: 'rgba(255,255,255,0.02)',
            border: '1px solid rgba(255,255,255,0.05)',
            borderRadius: '16px',
            padding: '1.5rem',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.6rem', color: 'rgba(255,255,255,0.4)', letterSpacing: '0.15em', marginBottom: '0.5rem' }}>
              {reality.hash}
            </div>
            <div style={{ fontSize: '2.5rem', fontWeight: '800', color: '#fff' }}>
              {stats.hash.toFixed(1)} EH
            </div>
            <div style={{ fontSize: '0.55rem', color: 'rgba(255,255,255,0.3)', letterSpacing: '0.05em', marginTop: '0.5rem' }}>
              {reality.pulse}
            </div>
          </div>
        </div>

        {/* Particle Overlay (CSS only for speed) */}
        <div style={{
          position: 'absolute',
          top: 0, left: 0, right: 0, bottom: 0,
          pointerEvents: 'none',
          backgroundImage: 'radial-gradient(circle at 50% 50%, rgba(255,255,255,0.05) 1px, transparent 1px)',
          backgroundSize: '30px 30px',
          opacity: 0.5
        }} />
      </div>
    </Section>
  );
}
