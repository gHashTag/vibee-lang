/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  optimizeFonts: false,
  eslint: {
    ignoreDuringBuilds: true,
  },
}

module.exports = nextConfig
