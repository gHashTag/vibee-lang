import { NextResponse } from 'next/server';
import createMiddleware from 'next-intl/middleware';

const intlMiddleware = createMiddleware({
  locales: ['en', 'ru'],
  defaultLocale: 'en'
});

export default function middleware(req) {
  const { pathname } = req.nextUrl;

  // Redirect root path to default locale
  if (pathname === '/') {
    return NextResponse.redirect(new URL('/en', req.url));
  }

  return intlMiddleware(req);
}

export const config = {
  matcher: ['/', '/(en|ru)/:path*']
};