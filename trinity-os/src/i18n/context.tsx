'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import en from '../../messages/en.json';
import ru from '../../messages/ru.json';
import de from '../../messages/de.json';
import zh from '../../messages/zh.json';
import es from '../../messages/es.json';

const translations: Record<string, any> = { en, ru, de, zh, es };
const LANGS = ['en', 'ru', 'de', 'zh', 'es'] as const;
type Lang = typeof LANGS[number];

interface I18nContextType {
  t: any;
  lang: string;
  setLang: (lang: string) => void;
  switchLang: () => void;
  availableLangs: readonly string[];
}

const I18nContext = createContext<I18nContextType | null>(null);

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>('en');
  const [mounted, setMounted] = useState(false);

  // Detect language on client side only
  useEffect(() => {
    // 1. Check URL param (highest priority)
    const urlParams = new URLSearchParams(window.location.search);
    const urlLang = urlParams.get('lang');
    if (urlLang && LANGS.includes(urlLang as Lang)) {
      setLangState(urlLang as Lang);
      localStorage.setItem('trinity-lang', urlLang);
      setMounted(true);
      return;
    }
    
    // 2. Check localStorage
    const saved = localStorage.getItem('trinity-lang');
    if (saved && LANGS.includes(saved as Lang)) {
      setLangState(saved as Lang);
      setMounted(true);
      return;
    }
    
    // 3. Detect from browser
    const browserLang = navigator.language.slice(0, 2);
    if (LANGS.includes(browserLang as Lang)) {
      setLangState(browserLang as Lang);
    }
    
    setMounted(true);
  }, []);

  // Save to localStorage when lang changes
  useEffect(() => {
    if (mounted) {
      localStorage.setItem('trinity-lang', lang);
      document.documentElement.lang = lang;
    }
  }, [lang, mounted]);

  const t = translations[lang] || translations['en'];

  const setLang = (newLang: string) => {
    if (LANGS.includes(newLang as Lang)) {
      setLangState(newLang as Lang);
    }
  };

  const switchLang = () => {
    const idx = LANGS.indexOf(lang);
    const nextIdx = (idx + 1) % LANGS.length;
    setLangState(LANGS[nextIdx]);
  };

  return (
    <I18nContext.Provider value={{ t, lang, setLang, switchLang, availableLangs: LANGS }}>
      {children}
    </I18nContext.Provider>
  );
}

export const useI18n = (): I18nContextType => {
  const context = useContext(I18nContext);
  if (!context) {
    return { t: translations['en'], lang: 'en', setLang: () => {}, switchLang: () => {}, availableLangs: LANGS };
  }
  return context;
};
