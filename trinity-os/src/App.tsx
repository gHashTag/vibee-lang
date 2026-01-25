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

      {/* TRINITY HARDWARE TRUTH: LIVE MINING MVP */}
      <section id="mining-live" style={{ minHeight: '100vh', borderBottom: '1px solid var(--border)', background: 'linear-gradient(180deg, rgba(0, 229, 153, 0.02) 0%, transparent 100%)' }}>
        <div className="tight fade" style={{ padding: '6rem 1.5rem 2rem', textAlign: 'center' }}>
          <div className="badge" style={{ marginBottom: '1rem' }}>Investor Proof-of-Concept</div>
          <h2 className="grad" style={{ fontSize: 'clamp(2rem, 5vw, 3.5rem)', marginBottom: '1.5rem' }}>Hardware Truth Demo</h2>
          <p style={{ maxWidth: '900px', margin: '0 auto 3rem', fontSize: '1.1rem', opacity: 0.9, lineHeight: 1.6, color: 'var(--text)' }}>
            Для инвестора этот блок — **материальное доказательство** превосходства Trinity. Мы не просто проектируем чипы, мы уже создали программный стек, 
            способный работать с реальным блокчейном на принципах SU(3). 
          </p>
          
          <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '2rem', maxWidth: '1000px', margin: '0 auto 4rem', textAlign: 'left' }}>
            <div className="premium-card compact" style={{ padding: '1.5rem' }}>
              <h4 style={{ color: 'var(--accent)', marginBottom: '0.5rem' }}>De-risking Фаза</h4>
              <p style={{ fontSize: '0.85rem', margin: 0, opacity: 0.8 }}>Алгоритмы проверены на реальном кремнии (ARM/FPGA). Логика SU(3) полностью готова к производству в ASIC.</p>
            </div>
            <div className="premium-card compact" style={{ padding: '1.5rem' }}>
              <h4 style={{ color: 'var(--accent)', marginBottom: '0.5rem' }}>Захват рынка</h4>
              <p style={{ fontSize: '0.85rem', margin: 0, opacity: 0.8 }}>Trinity превращает 7 млрд смартфонов в легальные и сверхприбыльные добывающие узлы без перегрева.</p>
            </div>
            <div className="premium-card compact" style={{ padding: '1.5rem' }}>
              <h4 style={{ color: 'var(--accent)', marginBottom: '0.5rem' }}>Экспоненциальный ROI</h4>
              <p style={{ fontSize: '0.85rem', margin: 0, opacity: 0.8 }}>578-кратный перевес в энергоэффективности — это единственный путь к выживанию майнинга после 2026 года.</p>
            </div>
          </div>
        </div>
        <div style={{ borderTop: '1px solid rgba(0, 229, 153, 0.1)', paddingTop: '2rem' }}>
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