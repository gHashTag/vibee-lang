import { useEffect, useRef, useState } from 'react'

export default function Section({ id, children, className = '' }) {
  const ref = useRef(null)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setVisible(true) },
      { threshold: 0.05 } // Trigger earlier
    )
    if (ref.current) observer.observe(ref.current)
    return () => observer.disconnect()
  }, [])

  return (
    <section id={id} ref={ref} className={`${className} ${visible ? 'visible' : ''}`}>
      {children}
    </section>
  )
}
