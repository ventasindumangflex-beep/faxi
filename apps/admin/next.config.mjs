/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ['@faxi/core'],
  poweredByHeader: false,
  async headers() {
    return [{ source: '/(.*)', headers: [{ key: 'X-Frame-Options', value: 'DENY' }, { key: 'Referrer-Policy', value: 'same-origin' }] }];
  },
};
export default nextConfig;
