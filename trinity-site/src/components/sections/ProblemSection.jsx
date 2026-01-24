import { useI18n } from '../../i18n/context'
import Section from '../Section'

export default function ProblemSection() {
  const { t } = useI18n()
  const p = t.problem
  
  return (
    <Section id="problem">
      <h2 className="fade" dangerouslySetInnerHTML={{ __html: p.title }} />
      <p className="sub fade">{p.sub}</p>
      
      <div className="glass fade bitnet-box">
        <h3>{p.bitnetTitle}</h3>
        <p dangerouslySetInnerHTML={{ __html: p.bitnetDesc }} />
      </div>
      
      <div className="vs fade">
        <div className="vs-side binary">
          <h4 className="vs-title">{p.binaryTitle}</h4>
          <div className="vs-flow">
            {p?.binaryFlow?.map((step, i) => (
              <span key={i}>{step}</span>
            ))}
          </div>
          <ul className="vs-stats">
            {p?.binaryStats?.map((stat, i) => (
              <li key={i} className="red">{stat}</li>
            ))}
          </ul>
        </div>
        
        <div className="vs-circle">→</div>
        
        <div className="vs-side trinity">
          <h4 className="vs-title">{p.trinityTitle}</h4>
          <div className="vs-flow">
            {p?.trinityFlow?.map((step, i) => (
              <span key={i}>{step}</span>
            ))}
          </div>
          <ul className="vs-stats">
            {p?.trinityStats?.map((stat, i) => (
              <li key={i} className="green">{stat}</li>
            ))}
          </ul>
        </div>
      </div>
      
      <blockquote className="quote-block fade">
        <p dangerouslySetInnerHTML={{ __html: p.quote }} />
        <cite>
          <a href="https://arxiv.org/abs/2402.17764" target="_blank" rel="noopener">
            {p.quoteSrc}
          </a>
        </cite>
      </blockquote>
    </Section>
  )
}
