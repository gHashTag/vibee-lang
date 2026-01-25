'use client';

import { createContext, useContext, useState, useEffect } from 'react';
import { useLocale } from 'next-intl';
import en from '../../messages/en.json';
import ru from '../../messages/ru.json';

const translations = { en, ru };

const I18nContext = createContext();

export function I18nProvider({ children }) {
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

export const useI18n = () => {
  const context = useContext(I18nContext);
  if (!context) {
    // Fallback if called outside provider (though it shouldn't happen with our setup)
    return { t: translations['en'], lang: 'en', switchLang: () => {} };
  }
  return context;
};
