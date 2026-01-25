import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import './index.css'
import App from './App.tsx'
import QuantumLab from './pages/QuantumLab.tsx'
import { I18nProvider } from './i18n/context.tsx'

// Register Service Worker for PWA
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {})
  })
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <I18nProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<App />} />
          <Route path="/quantum" element={<QuantumLab />} />
          <Route path="/lab" element={<QuantumLab />} />
          {/* Redirect old /viz/* routes to /quantum */}
          <Route path="/viz/*" element={<Navigate to="/quantum" replace />} />
        </Routes>
      </BrowserRouter>
    </I18nProvider>
  </StrictMode>,
)
