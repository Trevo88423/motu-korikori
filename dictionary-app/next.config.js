/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverActions: {
      bodySizeLimit: '5mb',
    },
  },
  outputFileTracingIncludes: {
    '/api/bible/random-verse': ['./data/bible-indices/**'],
  },
}

module.exports = nextConfig
