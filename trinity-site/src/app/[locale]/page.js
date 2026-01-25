import { 
  HeroSection, 
  ProblemSection, 
  SolutionSection, 
  WhyNowSection, 
  CalculatorSection, 
  TractionSection, 
  MarketSection, 
  ProductSection, 
  FinancialsSection, 
  BusinessModelSection, 
  TechnologySection, 
  ScienceProofSection, 
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
} from '../../components/sections'
import Navigation from '../../components/Navigation'
import QuantumBackground from '../../components/QuantumBackground'

export default function HomePage() {
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
      <ProductSection />
      <FinancialsSection />
      <BusinessModelSection />
      <TechnologySection />
      <ScienceProofSection />
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