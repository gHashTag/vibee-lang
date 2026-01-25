'use client';

import React from 'react';
import {NextIntlClientProvider} from 'next-intl';
import {I18nProvider} from '../i18n/context';

export function IntlProvider({ 
  children, 
  locale, 
  messages 
}: { 
  children: React.ReactNode; 
  locale: string; 
  messages: any; 
}) {
  return (
    <NextIntlClientProvider locale={locale} messages={messages}>
      <I18nProvider>
        {children}
      </I18nProvider>
    </NextIntlClientProvider>
  );
}