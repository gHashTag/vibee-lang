interface MetricCardProps {
  value: string | number;
  label: string;
  color?: 'green' | 'blue' | 'purple' | 'cyan' | 'yellow';
}

export default function MetricCard({ value, label }: MetricCardProps) {
  return (
    <div className="premium-card" style={{ padding: 'clamp(1rem, 4vw, 1.5rem)', minWidth: 0 }}>
      <div className="val" style={{ fontSize: 'clamp(1.4rem, 6vw, 2.5rem)', fontWeight: 600, color: 'var(--text)', marginBottom: '0.5rem', lineHeight: 1 }}>{value}</div>
      <div className="lbl" style={{ color: 'var(--muted)', fontSize: 'clamp(0.65rem, 2vw, 0.75rem)', lineHeight: 1.2, textTransform: 'uppercase', letterSpacing: '0.05em', overflowWrap: 'anywhere' }}>{label}</div>
    </div>
  )
}
