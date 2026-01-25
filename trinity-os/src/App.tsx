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
      
      {/* TRINITY HARDWARE TRUTH: LIVE MINING MVP */}
      <section id="mining-live" style={{ minHeight: '100vh', borderBottom: '1px solid var(--border)' }}>
        <MiningMVP />
      </section>

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