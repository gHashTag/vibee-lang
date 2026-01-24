'use client';

import {NextIntlClientProvider} from 'next-intl';

export function IntlProvider({ children, locale, messages }) {
  return (
    <NextIntlClientProvider locale={locale} messages={messages}>
      {children}
    </NextIntlClientProvider>
  );
}