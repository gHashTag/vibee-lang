"use client";
import { motion } from 'framer-motion'
import { useI18n } from '../i18n/context'

export default function Footer() {
  const { t } = useI18n()
  
  return (
    <footer style={{
      background: 'rgba(0,0,0,0.95)',
      borderTop: '1px solid var(--border)',
      padding: 'clamp(3rem, 8vw, 5rem) clamp(1rem, 5vw, 3rem)',
      marginTop: '4rem'
    }}>
      <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
        {/* Main Footer Content */}
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', 
          gap: '3rem',
          marginBottom: '3rem'
        }}>
          {/* Brand */}
          <div>
            <motion.div 
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              style={{ fontSize: '1.5rem', fontWeight: 700, marginBottom: '1rem' }}
            >
              TRINITY
            </motion.div>
            <p style={{ color: 'var(--muted)', fontSize: '0.85rem', lineHeight: 1.6 }}>
              {t.footer?.tagline || 'Ternary Computing Revolution'}
            </p>
            <div style={{ 
              marginTop: '1rem', 
              fontFamily: 'monospace', 
              color: 'var(--accent)', 
              fontSize: '0.9rem' 
            }}>
              φ² + 1/φ² = 3
            </div>
          </div>

          {/* Links */}
          <div>
            <h4 style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '1rem', color: 'var(--muted)' }}>
              {t.footer?.linksTitle || 'Links'}
            </h4>
            <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
              <li><a href="#problem" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7, transition: 'opacity 0.2s' }}>{t.nav?.problem || 'Problem'}</a></li>
              <li><a href="#solution" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7, transition: 'opacity 0.2s' }}>{t.nav?.solution || 'Solution'}</a></li>
              <li><a href="#technology" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7, transition: 'opacity 0.2s' }}>{t.nav?.technology || 'Technology'}</a></li>
              <li><a href="#invest" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7, transition: 'opacity 0.2s' }}>{t.nav?.invest || 'Invest'}</a></li>
            </ul>
          </div>

          {/* Visualizations */}
          <div>
            <h4 style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '1rem', color: 'var(--muted)' }}>
              {t.footer?.vizTitle || 'Quantum Visualizations'}
            </h4>
            <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
              <motion.li whileHover={{ x: 5 }}>
                <a href="/quantum-runtime.html" style={{ color: 'var(--accent)', textDecoration: 'none', fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span style={{ fontSize: '1rem' }}>🔮</span> 999 OS Runtime
                </a>
              </motion.li>
              <motion.li whileHover={{ x: 5 }}>
                <a href="/quantum" style={{ color: 'var(--accent)', textDecoration: 'none', fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span style={{ fontSize: '1rem' }}>⚛️</span> Quantum Particles
                </a>
              </motion.li>
              <motion.li whileHover={{ x: 5 }}>
                <a href="/quantum-runtime.html#quantum59" style={{ color: 'var(--accent)', textDecoration: 'none', fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span style={{ fontSize: '1rem' }}>🌌</span> Quantum Trinity
                </a>
              </motion.li>
              <motion.li whileHover={{ x: 5 }}>
                <a href="/quantum-runtime.html#quantumlife" style={{ color: 'var(--accent)', textDecoration: 'none', fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span style={{ fontSize: '1rem' }}>🧬</span> Quantum Life
                </a>
              </motion.li>
              <motion.li whileHover={{ x: 5 }}>
                <a href="/quantum-runtime.html#neuromorphic" style={{ color: 'var(--accent)', textDecoration: 'none', fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span style={{ fontSize: '1rem' }}>🧠</span> Neuromorphic
                </a>
              </motion.li>
              <motion.li whileHover={{ x: 5 }}>
                <a href="/quantum-runtime.html#consciousness" style={{ color: 'var(--accent)', textDecoration: 'none', fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span style={{ fontSize: '1rem' }}>👁️</span> Consciousness
                </a>
              </motion.li>
              <motion.li whileHover={{ x: 5 }}>
                <a href="/quantum-runtime.html#trinity" style={{ color: 'var(--accent)', textDecoration: 'none', fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span style={{ fontSize: '1rem' }}>🔺</span> Trinity Core
                </a>
              </motion.li>
            </ul>
          </div>

          {/* Contact */}
          <div>
            <h4 style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '1rem', color: 'var(--muted)' }}>
              {t.footer?.contactTitle || 'Contact'}
            </h4>
            <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
              <li>
                <a href="https://github.com/gHashTag/vibee-lang" target="_blank" rel="noopener" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7 }}>
                  GitHub
                </a>
              </li>
              <li>
                <a href="https://t.me/vibee_dev" target="_blank" rel="noopener" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7 }}>
                  Telegram
                </a>
              </li>
              <li>
                <a href="mailto:invest@trinity.dev" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7 }}>
                  invest@trinity.dev
                </a>
              </li>
            </ul>
          </div>
        </div>

        {/* Bottom Bar */}
        <div style={{ 
          borderTop: '1px solid var(--border)', 
          paddingTop: '2rem',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '1rem'
        }}>
          <div style={{ color: 'var(--muted)', fontSize: '0.75rem' }}>
            © 2024-2026 TRINITY. {t.footer?.rights || 'All rights reserved.'}
          </div>
          <div style={{ color: 'var(--muted)', fontSize: '0.75rem', fontFamily: 'monospace' }}>
            PHOENIX = 999 | KOSCHEI IS IMMORTAL
          </div>
        </div>
      </div>
    </footer>
  )
}
