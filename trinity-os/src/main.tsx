import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import './index.css'
import App from './App.tsx'
import VisualizationsPage from './pages/VisualizationsPage.tsx'
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
          <Route path="/quantum" element={<VisualizationsPage />} />
          <Route path="/visualizations" element={<VisualizationsPage />} />
        </Routes>
      </BrowserRouter>
    </I18nProvider>
  </StrictMode>,
)
