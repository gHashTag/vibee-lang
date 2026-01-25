import { lazy, Suspense } from 'react'
import { 
  HeroSection, 
  ProblemSection, 
  SolutionSection 
} from './components/sections'
import Navigation from './components/Navigation'
import QuantumBackground from './components/QuantumBackground'

// Lazy load секции ниже fold
const WhyNowSection = lazy(() => import('./components/sections/WhyNowSection'))
const CalculatorSection = lazy(() => import('./components/sections/CalculatorSection'))
const TractionSection = lazy(() => import('./components/sections/TractionSection'))
const MarketSection = lazy(() => import('./components/sections/MarketSection'))
const MiningSolutionSection = lazy(() => import('./components/sections/MiningSolutionSection'))
const ProductSection = lazy(() => import('./components/sections/ProductSection'))
const FinancialsSection = lazy(() => import('./components/sections/FinancialsSection'))
const BusinessModelSection = lazy(() => import('./components/sections/BusinessModelSection'))
const TechnologySection = lazy(() => import('./components/sections/TechnologySection'))
const InvestorProofSection = lazy(() => import('./components/sections/InvestorProofSection'))
const SU3MiningRealitySection = lazy(() => import('./components/SU3MiningRealitySection'))
const TechAssetsSection = lazy(() => import('./components/sections/TechAssetsSection'))
const CalculatorLogicSection = lazy(() => import('./components/sections/CalculatorLogicSection'))
const BenchmarksSection = lazy(() => import('./components/sections/BenchmarksSection'))
const ScientificFoundationSection = lazy(() => import('./components/sections/ScientificFoundationSection'))
const MilestonesSection = lazy(() => import('./components/sections/MilestonesSection'))
const VisionSection = lazy(() => import('./components/sections/VisionSection'))
const GTMSection = lazy(() => import('./components/sections/GTMSection'))
const CompetitionSection = lazy(() => import('./components/sections/CompetitionSection'))
const RoadmapSection = lazy(() => import('./components/sections/RoadmapSection'))
const TeamSection = lazy(() => import('./components/sections/TeamSection'))
const EcosystemSection = lazy(() => import('./components/sections/EcosystemSection'))
const InvestSection = lazy(() => import('./components/sections/InvestSection'))

// Минимальный fallback для секций
const SectionFallback = () => (
  <div style={{ minHeight: '50vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <div style={{ width: '40px', height: '40px', border: '3px solid var(--border)', borderTopColor: 'var(--accent)', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
  </div>
)

export default function App() {
  return (
    <main>
      <QuantumBackground />
      <Navigation />
      
      {/* Above fold - загружаются сразу */}
      <HeroSection />
      <ProblemSection />
      <SolutionSection />
      
      {/* Below fold - lazy loading */}
      <Suspense fallback={<SectionFallback />}>
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
      </Suspense>
    </main>
  )
}