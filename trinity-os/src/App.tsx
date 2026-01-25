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
      <section id="mining-live" style={{ minHeight: '100vh', borderBottom: '1px solid var(--border)', background: 'rgba(0, 229, 153, 0.01)' }}>
        <div className="tight fade" style={{ padding: '4rem 1.5rem 0', textAlign: 'center' }}>
          <h2 className="grad">Hardware Truth Demo</h2>
          <p style={{ maxWidth: '800px', margin: '1rem auto', fontSize: '0.9rem', opacity: 0.8 }}>
            Для инвестора этот блок — **гарантия реализации**. Мы не просто пишем код, мы симулируем нативную работу SU(3) ядра с реальной сетью Bitcoin. 
            Это доказывает дееспособность алгоритмов до массового выпуска чипов и открывает триллионный рынок мобильного майнинга.
          </p>
        </div>
        <MiningMVP />
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