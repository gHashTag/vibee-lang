import React, { useEffect, useRef, useState } from 'react'

interface SectionProps {
  id: string;
  children: React.ReactNode;
  className?: string;
  style?: React.CSSProperties;
}

export default function Section({ id, children, className = '', style }: SectionProps) {
  const ref = useRef<HTMLElement>(null)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setVisible(true) },
      { threshold: 0.01 }
    )
    if (ref.current) observer.observe(ref.current)
    return () => observer.disconnect()
  }, [])

  return (
    <section id={id} ref={ref} className={`${className} ${visible ? 'visible' : ''}`} style={style}>
      {children}
    </section>
  )
}
