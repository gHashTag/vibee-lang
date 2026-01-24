import { I18nProvider } from './i18n/context'
import QuantumBackground from './components/QuantumBackground'
import Navigation from './components/Navigation'
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
  GTMSection,
  CompetitionSection,
  RoadmapSection,
  TeamSection,
  EcosystemSection,
  InvestSection
} from './components/sections'

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
        <CalculatorSection />
        <TractionSection />
        <MarketSection />
        <ProductSection />
        <FinancialsSection />
        <BusinessModelSection />
        <GTMSection />
        <CompetitionSection />
        <RoadmapSection />
        <TeamSection />
        <EcosystemSection />
        <InvestSection />
      </main>
      <footer style={{ textAlign: 'center', padding: '3rem', color: 'var(--muted)', fontSize: '0.85rem' }}>
        <p>TRINITY Computing © 2026 | φ² + 1/φ² = 3</p>
      </footer>
    </I18nProvider>
  )
}
