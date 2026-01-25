'use client';

import {NextIntlClientProvider} from 'next-intl';
import {I18nProvider} from '../i18n/context.jsx';

export function IntlProvider({ children, locale, messages }) {
  return (
    <NextIntlClientProvider locale={locale} messages={messages}>
      <I18nProvider>
        {children}
      </I18nProvider>
    </NextIntlClientProvider>
  );
}