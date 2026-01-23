import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function HeroSection() {
  const { t } = useI18n()
  
  return (
    <Section id="hero">
      <p className="tag fade">{t.hero.tag}</p>
      <h1 className="fade">TRINITY</h1>
      <p className="formula fade">φ² + 1/φ² = 3</p>
      <p className="quote fade">{t.hero.quote}</p>
      <p className="sub fade" dangerouslySetInnerHTML={{ __html: t.hero.desc }} />
      <a href="#invest" className="btn fade">{t.hero.cta}</a>
    </Section>
  )
}
