"use client";
const colorMap = {
  green: '#00E599',
  blue: '#00E599',
  purple: '#bf5af2',
  cyan: '#64d2ff',
  yellow: '#ffd60a'
}

export default function MetricCard({ value, label, color = 'blue' }) {
  return (
    <div className="premium-card" style={{ padding: '2rem' }}>
      <div className="val" style={{ fontSize: '3rem', fontWeight: 500, color: 'var(--text)', marginBottom: '0.5rem' }}>{value}</div>
      <div className="lbl" style={{ color: 'var(--muted)', fontSize: '0.9rem' }}>{label}</div>
    </div>
  )
}
