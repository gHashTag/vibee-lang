"use client";

interface DataPoint {
  year: string;
  revenue: number;
  valuation: number;
}

const data: DataPoint[] = [
  { year: "2026", revenue: 2, valuation: 200 },
  { year: "2027", revenue: 15, valuation: 500 },
  { year: "2028", revenue: 80, valuation: 2000 },
  { year: "2029", revenue: 300, valuation: 5000 },
  { year: "2030", revenue: 1000, valuation: 10000 },
];

export default function GrowthChart() {
  const maxVal = 10000;
  const height = 300;
  const width = 800;
  const padding = 40;

  const points = data.map((d, i) => {
    const x = padding + (i / (data.length - 1)) * (width - 2 * padding);
    const y = height - padding - (d.valuation / maxVal) * (height - 2 * padding);
    return `${x},${y}`;
  }).join(" ");

  return (
    <div className="premium-card fade" style={{ width: '100%', maxWidth: '900px', margin: '3rem auto', padding: 'clamp(1rem, 4vw, 2rem)' }}>
      <h3 style={{ textAlign: 'center', marginBottom: '2rem', fontSize: 'clamp(1rem, 4vw, 1.2rem)' }}>Valuation Growth Projection (LOG Scale)</h3>
      <div style={{ width: '100%' }}>
        <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
          {[0, 0.25, 0.5, 0.75, 1].map((tick) => (
             <line 
               key={tick} 
               x1={padding} 
               y1={height - padding - tick * (height - 2 * padding)} 
               x2={width - padding} 
               y2={height - padding - tick * (height - 2 * padding)} 
               stroke="var(--border)" 
               strokeDasharray="4 4" 
             />
          ))}

          <path
            d={points ? `M ${points} ${width - padding},${height - padding} ${padding},${height - padding} Z` : ""}
            fill="url(#grad1)"
            opacity="0.3"
          />

          <polyline
            className="draw-path"
            fill="none"
            stroke="var(--accent)"
            strokeWidth="3"
            points={points || ""}
          />

          {data.map((d, i) => {
             const x = padding + (i / (data.length - 1)) * (width - 2 * padding);
             const y = height - padding - (d.valuation / maxVal) * (height - 2 * padding);
             return (
               <g key={i} className={`anim-fade-in-up anim-delay-${i * 2 + 5}`}>
                 <circle cx={x} cy={y} r="5" fill="var(--bg)" stroke="var(--accent)" strokeWidth="2" />
                 <text x={x} y={y - 15} textAnchor="middle" fill="var(--text)" fontSize="12" fontWeight="600">
                   ${d.valuation >= 1000 ? d.valuation / 1000 + 'B' : d.valuation + 'M'}
                 </text>
                 <text x={x} y={height - 10} textAnchor="middle" fill="var(--muted)" fontSize="12">{d.year}</text>
               </g>
             )
          })}

          <defs>
            <linearGradient id="grad1" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stopColor="var(--accent)" stopOpacity="0.5" />
              <stop offset="100%" stopColor="var(--accent)" stopOpacity="0" />
            </linearGradient>
          </defs>
        </svg>
      </div>
    </div>
  );
}
