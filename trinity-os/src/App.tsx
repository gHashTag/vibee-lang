import { 
  HeroSection, 
  ProblemSection, 
  SolutionSection, 
  WhyNowSection, 
  CalculatorSection, 
  TractionSection, 
  MarketSection, 
  MiningSolutionSection,
  ProductSection, 
  FinancialsSection, 
  BusinessModelSection, 
  TechnologySection, 
  TechAssetsSection, 
  CalculatorLogicSection, 
  BenchmarksSection, 
  ScientificFoundationSection, 
  MilestonesSection, 
  VisionSection, 
  GTMSection, 
  CompetitionSection, 
  RoadmapSection, 
  TeamSection, 
  EcosystemSection, 
  InvestSection 
} from './components/sections'
import Navigation from './components/Navigation'
import QuantumBackground from './components/QuantumBackground'
import MiningMVP from './components/MiningMVP'

export default function App() {
  return (
    <main>
      <QuantumBackground />
      <Navigation />
      <HeroSection />
      
      <ProblemSection />
      <SolutionSection />
      <WhyNowSection />
      <CalculatorSection />
      <TractionSection />
      <MarketSection />
      <MiningSolutionSection />
      <ProductSection />
      <FinancialsSection />
      <BusinessModelSection />
      <TechnologySection />

      {/* TRINITY INVESTOR PROOF: HARDWARE TRUTH DEMO */}
      <section id="mining-live" style={{ 
        position: 'relative',
        minHeight: '120vh', 
        borderBottom: '1px solid var(--border)', 
        background: 'linear-gradient(180deg, rgba(0, 229, 153, 0.03) 0%, transparent 100%)',
        zIndex: 10,
        padding: '100px 0'
      }}>
        <div className="tight fade" style={{ padding: '0 1.5rem', textAlign: 'center', marginBottom: '60px' }}>
          <div className="badge" style={{ marginBottom: '1.5rem', display: 'inline-block' }}>INVESTOR PROOF-OF-CONCEPT</div>
          <h2 className="grad" style={{ fontSize: 'clamp(2.5rem, 6vw, 4rem)', marginBottom: '1.5rem', lineHeight: 1.1 }}>Hardware Truth Demo</h2>
          <p style={{ maxWidth: '900px', margin: '0 auto 4rem', fontSize: '1.2rem', opacity: 0.9, lineHeight: 1.6, color: '#fff' }}>
            Для инвестора этот блок — **материальное доказательство** превосходства Trinity. Мы не просто проектируем чипы, мы уже создали программный стек, 
            способный работать с реальным блокчейном на принципах SU(3). 
          </p>
          
          <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '2rem', maxWidth: '1100px', margin: '0 auto', textAlign: 'left' }}>
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
        </div>
        
        <div style={{ position: 'relative', width: '100%', borderTop: '1px solid rgba(0, 229, 153, 0.1)' }}>
          <MiningMVP />
        </div>
      </section>

      <TechAssetsSection />
      <CalculatorLogicSection />
      <BenchmarksSection />
      <ScientificFoundationSection />
      <MilestonesSection />
      <VisionSection />
      <GTMSection />
      <CompetitionSection />
      <RoadmapSection />
      <TeamSection />
      <EcosystemSection />
      <InvestSection />
    </main>
  );
}