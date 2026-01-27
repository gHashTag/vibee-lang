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
  const [lang, setLangState] = useState<Lang>(() => {
    // Client-side only initialization
    if (typeof window !== 'undefined') {
      console.log('Detecting language on init...');
      // 1. Check URL param (highest priority)
      const urlParams = new URLSearchParams(window.location.search);
      const urlLang = urlParams.get('lang');
      if (urlLang && LANGS.includes(urlLang as Lang)) {
        console.log('Language from URL:', urlLang);
        localStorage.setItem('trinity-lang', urlLang);
        return urlLang as Lang;
      }
      
      // 2. Check localStorage
      const saved = localStorage.getItem('trinity-lang');
      if (saved && LANGS.includes(saved as Lang)) {
        console.log('Language from localStorage:', saved);
        return saved as Lang;
      }
      
      // 3. Detect from browser - DISABLED (Force English Default)
      // const browserLang = navigator.language.slice(0, 2);
      // console.log('Browser language:', browserLang);
      // if (LANGS.includes(browserLang as Lang)) {
      //   console.log('Setting language from browser:', browserLang);
      //   return browserLang as Lang;
      // }
    }
    // Default fallback
    return 'en';
  });
  const [mounted, setMounted] = useState(false);

  // Set mounted flag on client
  useEffect(() => {
    setMounted(true);
  }, []);

  // Save to localStorage when lang changes
  useEffect(() => {
    if (mounted) {
      console.log('Saving language to localStorage:', lang);
      localStorage.setItem('trinity-lang', lang);
      document.documentElement.lang = lang;
    }
  }, [lang, mounted]);

  // Deep merge with English fallback to prevent crashes on missing keys
  const deepMerge = (base: any, override: any): any => {
    if (!override) return base;
    if (typeof base !== 'object' || typeof override !== 'object') return override;
    
    const merged = { ...base };
    for (const key in override) {
      if (typeof override[key] === 'object' && override[key] !== null && !Array.isArray(override[key])) {
        merged[key] = deepMerge(base[key] || {}, override[key]);
      } else {
        merged[key] = override[key];
      }
    }
    return merged;
  };

  const currentLangT = translations[lang] || translations['en'];
  const t = lang === 'en' ? currentLangT : deepMerge(translations['en'], currentLangT);

  const setLang = (newLang: string) => {
    console.log('Setting language:', newLang, 'current:', lang);
    if (LANGS.includes(newLang as Lang)) {
      setLangState(newLang as Lang);
    } else {
      console.warn('Invalid language:', newLang);
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
