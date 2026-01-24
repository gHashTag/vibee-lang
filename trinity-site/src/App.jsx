import { I18nProvider } from './i18n/context.jsx'
import QuantumBackground from './components/QuantumBackground.jsx'
import Navigation from './components/Navigation.jsx'
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
} from './components/sections/index.js'

export default function App() {
  return (
    <I18nProvider>
      <QuantumBackground />
      <Navigation />
      <main>
        <HeroSection />
        <ProblemSection />
        <SolutionSection />
        <WhyNowSection />
        <ScienceProofSection />
        <CalculatorSection />
        <TractionSection />
        <MarketSection />
        <ProductSection />
        <FinancialsSection />
        <BusinessModelSection />
        <TechnologySection />
        <TechAssetsSection />
        <CalculatorLogicSection />
        <BenchmarksSection />
        <ScientificFoundationSection />
        <MilestonesSection />
        <GTMSection />
        <CompetitionSection />
        <RoadmapSection />
        <TeamSection />
        <EcosystemSection />
        <VisionSection />
        <InvestSection />
      </main>
      <footer style={{ textAlign: 'center', padding: '3rem', color: 'var(--muted)', fontSize: '0.85rem' }}>
        <p>TRINITY Computing © 2026 | φ² + 1/φ² = 3</p>
      </footer>
    </I18nProvider>
  )
}
