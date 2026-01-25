import { useEffect, useRef } from 'react'

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
}

export default function QuantumBackground() {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    
    let mouseX = -1000, mouseY = -1000
    let particles: Particle[] = []
    let animationId: number
    
    const resize = () => {
      canvas.width = window.innerWidth
      canvas.height = window.innerHeight
      initParticles()
    }
    
    const isMobile = () => window.innerWidth < 768
    
    const initParticles = () => {
      particles = []
      const mobile = isMobile()
      const density = mobile ? 40 : 25
      const count = Math.min(mobile ? 30 : 60, Math.floor(canvas.width / density))
      for (let i = 0; i < count; i++) {
        particles.push({
          x: Math.random() * canvas.width,
          y: Math.random() * canvas.height,
          vx: (Math.random() - 0.5) * (mobile ? 0.2 : 0.3),
          vy: (Math.random() - 0.5) * (mobile ? 0.2 : 0.3),
          radius: Math.random() * (mobile ? 1.2 : 1.5) + 0.5
        })
      }
    }
    
    const update = (p: Particle) => {
      const mobile = isMobile()
      const interactionDist = mobile ? 100 : 150
      
      const dx = mouseX - p.x
      const dy = mouseY - p.y
      const dist = Math.sqrt(dx * dx + dy * dy)
      
      if (dist < interactionDist && dist > 0) {
        const force = (1 - dist / interactionDist) * (mobile ? 0.3 : 0.5)
        p.vx -= (dx / dist) * force
        p.vy -= (dy / dist) * force
      }
      
      p.x += p.vx
      p.y += p.vy
      p.vx *= 0.99
      p.vy *= 0.99
      
      if (p.x < 0) p.x = canvas.width
      if (p.x > canvas.width) p.x = 0
      if (p.y < 0) p.y = canvas.height
      if (p.y > canvas.height) p.y = 0
    }
    
    const draw = (p: Particle) => {
      ctx.beginPath()
      ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2)
      ctx.fillStyle = 'rgba(255,255,255,0.4)'
      ctx.fill()
    }
    
    const drawConnections = () => {
      const mobile = isMobile()
      const connectionDist = mobile ? 80 : 100
      const maxConnections = mobile ? 2 : 4
      
      for (let i = 0; i < particles.length; i++) {
        let connections = 0
        for (let j = i + 1; j < particles.length && connections < maxConnections; j++) {
          const dx = particles[j].x - particles[i].x
          const dy = particles[j].y - particles[i].y
          const dist = Math.sqrt(dx * dx + dy * dy)
          
          if (dist < connectionDist) {
            ctx.beginPath()
            ctx.moveTo(particles[i].x, particles[i].y)
            ctx.lineTo(particles[j].x, particles[j].y)
            ctx.strokeStyle = `rgba(255,255,255,${(1 - dist / connectionDist) * 0.1})`
            ctx.lineWidth = 0.5
            ctx.stroke()
            connections++
          }
        }
      }
    }
    
    const animate = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height)
      drawConnections()
      particles.forEach(p => { update(p); draw(p) })
      animationId = requestAnimationFrame(animate)
    }
    
    const handleMouseMove = (e: MouseEvent) => { mouseX = e.clientX; mouseY = e.clientY }
    const handleMouseLeave = () => { mouseX = -1000; mouseY = -1000 }
    const handleTouchMove = (e: TouchEvent) => { mouseX = e.touches[0].clientX; mouseY = e.touches[0].clientY }
    const handleTouchEnd = () => { mouseX = -1000; mouseY = -1000 }
    
    resize()
    window.addEventListener('resize', resize)
    document.addEventListener('mousemove', handleMouseMove)
    document.addEventListener('mouseleave', handleMouseLeave)
    document.addEventListener('touchmove', handleTouchMove, { passive: true })
    document.addEventListener('touchstart', handleTouchMove, { passive: true })
    document.addEventListener('touchend', handleTouchEnd, { passive: true })
    animate()
    
    return () => {
      cancelAnimationFrame(animationId)
      window.removeEventListener('resize', resize)
      document.removeEventListener('mousemove', handleMouseMove)
      document.removeEventListener('mouseleave', handleMouseLeave)
      document.removeEventListener('touchmove', handleTouchMove as any)
      document.removeEventListener('touchstart', handleTouchMove as any)
      document.removeEventListener('touchend', handleTouchEnd)
    }
  }, [])

  return (
    <div className="quantum-bg">
      <canvas ref={canvasRef} className="quantum-canvas" />
    </div>
  )
}
