import { I18nProvider } from './i18n/context'
import QuantumBackground from './components/QuantumBackground'
import Navigation from './components/Navigation'
import {
  HeroSection,
  ProblemSection,
  SolutionSection,
  TractionSection,
  MarketSection,
  CompetitionSection,
  TeamSection,
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
        <TractionSection />
        <MarketSection />
        <CompetitionSection />
        <TeamSection />
        <InvestSection />
      </main>
      <footer>
        <p>TRINITY Computing © 2024 | φ² + 1/φ² = 3</p>
      </footer>
    </I18nProvider>
  )
}
