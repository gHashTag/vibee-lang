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
  InvestSection,
  InvestorProofSection
} from './components/sections'
import Navigation from './components/Navigation'
import QuantumBackground from './components/QuantumBackground'
import Section from './components/Section'
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
      <InvestorProofSection />

      {/* TRINITY HARDWARE TRUTH: LIVE MINING PREVIEW */}
      <Section id="mining-live">
        <div className="tight fade" style={{ textAlign: 'center', marginBottom: '4rem' }}>
          <h2 className="grad">SU(3) Mining Reality</h2>
          <p>Живая демонстрация взаимодействия троичной логики с сетью Bitcoin</p>
        </div>
        <div style={{ border: '1px solid rgba(0, 229, 153, 0.1)', borderRadius: '24px', overflow: 'hidden', background: '#000' }}>
          <MiningMVP />
        </div>
      </Section>

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