import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import './index.css'
import App from './App.tsx'
import QuantumLab from './pages/QuantumLab.tsx'
import Playground from './pages/Playground.tsx'
import { I18nProvider } from './i18n/context.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <I18nProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<App />} />
          <Route path="/quantum" element={<QuantumLab />} />
          <Route path="/lab" element={<QuantumLab />} />
          <Route path="/play" element={<Playground />} />
          <Route path="/viz/*" element={<Navigate to="/quantum" replace />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </I18nProvider>
  </StrictMode>,
)
