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
import SU3MiningRealitySection from './components/SU3MiningRealitySection'
// MiningMVP removed

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

      <SU3MiningRealitySection />

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