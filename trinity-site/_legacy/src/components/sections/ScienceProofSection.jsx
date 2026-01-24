import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function ScienceProofSection() {
  const { t } = useI18n()
  const s = t.science

  if (!s) return null

  return (
    <Section id="science">
      <div className="radial-glow" style={{ opacity: 0.1 }} />
      <div className="tight fade">
        <h2 dangerouslySetInnerHTML={{ __html: s.title }} />
        <p>{s.sub}</p>
      </div>

      <div className="grid fade" style={{ marginTop: '3rem', marginBottom: '4rem' }}>
        {s.stats?.map((stat, i) => (
          <div key={i} className="premium-card" style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '2.5rem', fontWeight: 500, color: 'var(--accent)', marginBottom: '0.5rem' }}>{stat.value}</div>
            <div style={{ color: 'var(--muted)', fontSize: '0.9rem' }}>{stat.label}</div>
          </div>
        ))}
      </div>

      <div className="fade" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '2rem', textAlign: 'left', marginBottom: '4rem' }}>
        <div className="premium-card compact" style={{ background: 'rgba(255,255,255,0.02)' }}>
           <h4 style={{ marginBottom: '1rem', color: 'var(--text)', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>Evidence by Field</h4>
           <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'x' }}>
             {s.sections?.map((sec, i) => (
               <div key={i} style={{ padding: '0.5rem 0', borderBottom: '1px solid var(--border)', fontSize: '0.85rem', color: 'var(--muted)', display: 'flex', justifyContent: 'space-between' }}>
                 <span>{sec.name}</span>
                 <span style={{ color: sec.passed === sec.total ? 'var(--accent)' : 'var(--text)' }}>{sec.passed}/{sec.total}</span>
               </div>
             ))}
           </div>
        </div>

        <div className="premium-card compact" style={{ background: 'rgba(255,255,255,0.02)' }}>
           <h4 style={{ marginBottom: '1rem', color: 'var(--text)', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>Key Formulas</h4>
           {s.formulas?.map((f, i) => (
             <div key={i} style={{ padding: '0.7rem 0', borderBottom: '1px solid var(--border)' }}>
               <div style={{ fontFamily: 'monospace', color: 'var(--accent)', fontSize: '0.95rem' }}>{f.formula}</div>
               <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.75rem', marginTop: '0.3rem', color: 'var(--muted)' }}>
                 <span>{f.desc}</span>
                 <span>Err: {f.error}</span>
               </div>
             </div>
           ))}
        </div>
      </div>
      
      <div className="fade" style={{ marginTop: '3rem' }}>
        <div style={{ display: 'flex', justifyContent: 'center', gap: '2rem', flexWrap: 'wrap' }}>
          {s.sources?.map((src, i) => (
             <div key={i} style={{ textAlign: 'center', width: '250px' }}>
                <div style={{ fontSize: '0.8rem', fontWeight: 500, color: 'var(--text)', marginBottom: '0.3rem' }}>{src.title}</div>
                <div style={{ fontSize: '0.75rem', color: 'var(--muted)' }}>{src.desc}</div>
             </div>
          ))}
        </div>
      </div>
    </Section>
  )
}
