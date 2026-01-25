interface MetricCardProps {
  value: string | number;
  label: string;
  color?: 'green' | 'blue' | 'purple' | 'cyan' | 'yellow';
}

export default function MetricCard({ value, label }: MetricCardProps) {
  return (
    <div className="premium-card" style={{ 
      padding: 'clamp(1rem, 3vw, 2rem)', 
      minWidth: 0, 
      height: '100%', 
      display: 'flex', 
      flexDirection: 'column', 
      justifyContent: 'center', 
      textAlign: 'center' 
    }}>
      <div className="val" style={{ fontSize: 'clamp(1.5rem, 5vw, 2.8rem)', fontWeight: 600, color: 'var(--text)', marginBottom: '0.5rem', lineHeight: 1 }}>{value}</div>
      <div className="lbl" style={{ color: 'var(--muted)', fontSize: '0.7rem', lineHeight: 1.2, textTransform: 'uppercase', letterSpacing: '0.1em', opacity: 0.8 }}>{label}</div>
    </div>
  )
}
