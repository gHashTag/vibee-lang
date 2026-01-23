const colorMap = {
  green: 'var(--green)',
  blue: 'var(--accent)',
  purple: '#bf5af2',
  cyan: '#64d2ff',
  yellow: '#ffd60a'
}

export default function MetricCard({ value, label, color = 'blue' }) {
  return (
    <div className="card glass">
      <div className="glow" style={{ background: `radial-gradient(circle, ${colorMap[color]}33, transparent)` }} />
      <div className="val" style={{ color: colorMap[color] }}>{value}</div>
      <div className="lbl">{label}</div>
    </div>
  )
}
