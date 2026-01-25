'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import { useLocale } from 'next-intl';
import en from '../../messages/en.json';
import ru from '../../messages/ru.json';

type TranslationType = typeof en;
const translations: Record<string, TranslationType> = { en, ru };

interface I18nContextType {
  t: TranslationType;
  lang: string;
  switchLang: () => void;
}

const I18nContext = createContext<I18nContextType | null>(null);

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const locale = useLocale();
  const [lang, setLang] = useState(locale);

  useEffect(() => {
    setLang(locale);
  }, [locale]);

  const t = translations[lang] || translations['en'];

  const switchLang = () => {
    const newLang = lang === 'en' ? 'ru' : 'en';
    window.location.href = `/${newLang}`;
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
