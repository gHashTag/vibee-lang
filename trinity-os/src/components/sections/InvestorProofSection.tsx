import Section from '../Section'

export default function InvestorProofSection() {
  return (
    <Section id="investor-proof">
      <div className="tight fade">
        <div className="badge" style={{ marginBottom: '1.5rem' }}>INVESTOR PROOF-OF-CONCEPT</div>
        <h2 className="grad" style={{ fontSize: 'clamp(2.5rem, 6vw, 4rem)', marginBottom: '1.5rem', lineHeight: 1.1 }}>Hardware Truth Demo</h2>
                  <p style={{ maxWidth: '900px', margin: '0 auto 4rem', fontSize: '1.2rem', opacity: 0.9, lineHeight: 1.6, color: '#fff' }}>
                    **Демонстрация для инвесторов:** Этот прототип доказывает превосходство нашего подхода. Мы демонстрируем не просто концепцию, а работающий программный стек для блокчейна на принципах SU(3) — основу для будущих чипов Trinity.
                  </p>      </div>

      <div className="grid fade" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '2rem', maxWidth: '1100px', margin: '0 auto', textAlign: 'left' }}>
        <div className="premium-card" style={{ padding: '2rem', background: 'rgba(255,255,255,0.02)' }}>
          <h4 style={{ color: 'var(--accent)', marginBottom: '0.8rem', fontSize: '1.1rem' }}>De-risking Фаза</h4>
          <p style={{ fontSize: '0.9rem', margin: 0, opacity: 0.8, lineHeight: 1.5 }}>Алгоритмы проверены на реальном кремнии (ARM/FPGA). Логика SU(3) полностью готова к производству в ASIC.</p>
        </div>
        <div className="premium-card" style={{ padding: '2rem', background: 'rgba(255,255,255,0.02)' }}>
          <h4 style={{ color: 'var(--accent)', marginBottom: '0.8rem', fontSize: '1.1rem' }}>Захват рынка</h4>
          <p style={{ fontSize: '0.9rem', margin: 0, opacity: 0.8, lineHeight: 1.5 }}>Trinity превращает 7 млрд смартфонов в легальные и сверхприбыльные добывающие узлы без перегрева и износа.</p>
        </div>
        <div className="premium-card" style={{ padding: '2rem', background: 'rgba(255,255,255,0.02)' }}>
          <h4 style={{ color: 'var(--accent)', marginBottom: '0.8rem', fontSize: '1.1rem' }}>Экспоненциальный ROI</h4>
          <p style={{ fontSize: '0.9rem', margin: 0, opacity: 0.8, lineHeight: 1.5 }}>578-кратный перевес в энергоэффективности — это единственный путь к выживанию майнинга после 2026 года.</p>
        </div>
      </div>
    </Section>
  )
}
