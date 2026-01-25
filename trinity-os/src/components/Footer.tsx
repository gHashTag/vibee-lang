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

          {/* Quantum Lab */}
          <div>
            <h4 style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '1rem', color: 'var(--muted)' }}>
              {t.footer?.vizTitle || 'Quantum Lab'}
            </h4>
            <motion.a 
              href="/quantum"
              whileHover={{ scale: 1.02 }}
              style={{ 
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem',
                padding: '1rem',
                background: 'rgba(0, 229, 153, 0.1)',
                border: '1px solid rgba(0, 229, 153, 0.2)',
                borderRadius: '12px',
                textDecoration: 'none',
                marginBottom: '1rem'
              }}
            >
              <span style={{ fontSize: '2rem' }}>🔮</span>
              <div>
                <div style={{ color: 'var(--accent)', fontWeight: 600, fontSize: '1rem' }}>
                  Launch Quantum Lab
                </div>
                <div style={{ color: 'var(--muted)', fontSize: '0.75rem' }}>
                  29 interactive visualizations
                </div>
              </div>
            </motion.a>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
              {['⚛️', '🧠', '🌊', '🔗', '🌀', '👁️', '🔺', '🔥'].map((icon, i) => (
                <a 
                  key={i}
                  href="/quantum" 
                  style={{ 
                    padding: '0.5rem',
                    background: 'rgba(255,255,255,0.05)',
                    borderRadius: '8px',
                    textDecoration: 'none',
                    fontSize: '1.2rem'
                  }}
                >
                  {icon}
                </a>
              ))}
            </div>
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
                <a href="mailto:raoffonom@icloud.com" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7 }}>
                  raoffonom@icloud.com
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
