/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ['@faxi/core'],
  poweredByHeader: false,
  // Textos legales en src/legal/*.md, importados como texto
  webpack(config) {
    config.module.rules.push({ test: /\.md$/, type: 'asset/source' });
    return config;
  },
  async headers() {
    return [{ source: '/(.*)', headers: [{ key: 'X-Frame-Options', value: 'DENY' }, { key: 'Referrer-Policy', value: 'same-origin' }] }];
  },
};
export default nextConfig;
