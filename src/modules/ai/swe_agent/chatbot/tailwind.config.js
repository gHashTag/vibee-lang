/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        vibee: {
          purple: '#a855f7',
          dark: '#0f172a',
        },
      },
    },
  },
  plugins: [],
}
