import { Inter } from "next/font/google";
import "./globals.css"; // Import global CSS here

const inter = Inter({ subsets: ["latin"] });

export const metadata = {
  title: "TRINITY Computing",
  description: "Native Ternary Hardware for AI. 5x Faster Inference.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en"> {/* Default lang */}
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet" />
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet" />
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600&display=swap" rel="stylesheet" />
      </head>
      <body className={inter.className}>
        {children}
      </body>
    </html>
  );
}