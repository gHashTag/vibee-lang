'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import en from '../../messages/en.json';
import ru from '../../messages/ru.json';

const translations: Record<string, any> = { en, ru };

interface I18nContextType {
  t: any;
  lang: string;
  switchLang: () => void;
}

const I18nContext = createContext<I18nContextType | null>(null);

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLang] = useState(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('trinity-lang');
      if (saved && translations[saved]) return saved;
      const urlParams = new URLSearchParams(window.location.search);
      const urlLang = urlParams.get('lang');
      if (urlLang && translations[urlLang]) return urlLang;
      return navigator.language.startsWith('ru') ? 'ru' : 'en';
    }
    return 'en';
  });

  useEffect(() => {
    localStorage.setItem('trinity-lang', lang);
    document.documentElement.lang = lang;
  }, [lang]);

  const t = translations[lang] || translations['en'];

  const switchLang = () => {
    setLang(prev => prev === 'en' ? 'ru' : 'en');
  };

  return (
    <I18nContext.Provider value={{ t, lang, switchLang }}>
      {children}
    </I18nContext.Provider>
  );
}

export const useI18n = (): I18nContextType => {
  const context = useContext(I18nContext);
  if (!context) {
    return { t: translations['en'], lang: 'en', switchLang: () => {} };
  }
  return context;
};
